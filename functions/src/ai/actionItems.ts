/**
 * Extract action items from conversation using OpenAI GPT
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import OpenAI from 'openai';

interface Message {
  id: string;
  senderName: string;
  text: string;
  type: 'text' | 'image';
  createdAt: admin.firestore.Timestamp;
}

/**
 * Extract action items with owners and deadlines
 */
export const extractActionItems = functions
  .runWith({
    timeoutSeconds: 60,
    memory: '512MB',
  })
  .https.onCall(
  async (data, context) => {
    // Check authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }
    
    const conversationId = data.conversationId as string;
    
    if (!conversationId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'conversationId is required'
      );
    }
    
    console.log(`🤖 Extracting action items: ${conversationId}`);
    
    try {
      // Fetch last 100 messages
      const messagesRef = admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', 'desc')
        .limit(100);
      
      const messagesSnapshot = await messagesRef.get();
      
      if (messagesSnapshot.empty) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'No messages to analyze'
        );
      }
      
      // Format messages as transcript
      const messages = messagesSnapshot.docs
        .map(doc => doc.data() as Message)
        .reverse();
      
      const transcript = messages.map(msg => {
        if (msg.type === 'text') {
          return `${msg.senderName}: ${msg.text}`;
        } else {
          return `${msg.senderName}: [sent a photo]`;
        }
      }).join('\n');
      
      // Call OpenAI API
      const apiKey = functions.config().openai?.key;
      
      if (!apiKey) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'OpenAI API key not configured'
        );
      }
      
      const openai = new OpenAI({
        apiKey: apiKey,
      });
      
      const response = await openai.chat.completions.create({
        model: 'gpt-4o',
        max_tokens: 1000,
        temperature: 0.7,
        messages: [{
          role: 'system',
          content: 'You are an intelligent assistant extracting SPECIFIC TASKS from team conversations. An action item is a concrete task requiring someone to DO something. Extract tasks with owners and deadlines. Return as JSON array. Never use hyphens.',
        }, {
          role: 'user',
          content: `Extract action items from this conversation. An ACTION ITEM is a SPECIFIC TASK requiring someone to DO something concrete.

✅ EXTRACT these as action items:
- Direct assignments: "Bob, review PR #234 by Friday"
- Personal commitments: "I'll send the report tomorrow"
- Commands: "You must finish the assignment"
- Requirements: "Make sure to attend the standup"
- Imperatives: "Submit the proposal by EOD"
- Collective tasks: "We need to schedule the meeting"
- Urgent actions: "ASAP: Review the PR"

❌ DO NOT extract these:
- Questions without commitment: "Should we meet tomorrow?"
- Informational statements: "The meeting is tomorrow"
- Casual suggestions: "Maybe we could grab coffee"
- Reactions: "That sounds good"
- Just urgency flags: "Important" or "Urgent" alone without a task
- Observations: "The deadline is Friday" (just stating fact)
- Vague possibilities: "We might need to..."

For EACH action item found, return JSON:
{
  "title": "Specific task description (what needs to be done)",
  "assignee": "Person name if mentioned, or null",
  "dueDate": "Natural language like 'friday', 'tomorrow', 'next week', or null",
  "confidence": 0.8,
  "sourceMsgIds": []
}

Rules:
- Extract ONLY specific tasks requiring action
- Include assignee if mentioned in message
- Include deadline if mentioned
- If unsure, lean toward INCLUDING (better to extract than miss)
- Return empty array [] if no valid action items

Conversation:
${transcript}`,
        }],
      });
      
      const responseText = response.choices[0]?.message?.content || '[]';
      
      // Parse JSON response
      let parsedItems: any[] = [];
      try {
        // Extract JSON from response (might have markdown code fences)
        const jsonMatch = responseText.match(/\[[\s\S]*\]/);
        const jsonText = jsonMatch ? jsonMatch[0] : responseText;
        parsedItems = JSON.parse(jsonText);
      } catch (error) {
        console.log('⚠️ Failed to parse JSON, using raw text format');
        parsedItems = [];
      }
      
      // CRITICAL FIX: Do NOT create insight popup (would show to all participants)
      // Action items are now managed in dedicated ActionItemsView panel
      // Only the requesting device should see results, not via broadcast popup
      console.log(`ℹ️ Skipping insight creation - using ActionItemsView panel instead`);
      
      // CRITICAL FIX: Create individual ActionItem documents for CRUD operations
      const actionItemsCollection = admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .collection('actionItems');
      
      const createdItems: any[] = [];
      
      for (const item of parsedItems) {
        const itemRef = actionItemsCollection.doc();
        
        // Parse due date if provided
        let dueDate = null;
        if (item.dueDate && item.dueDate !== 'null') {
          // Simple date parsing for common phrases
          const now = new Date();
          const dueDateLower = item.dueDate.toLowerCase();
          
          if (dueDateLower.includes('today')) {
            dueDate = now;
          } else if (dueDateLower.includes('tomorrow')) {
            dueDate = new Date(now.getTime() + 24 * 60 * 60 * 1000);
          } else if (dueDateLower.includes('friday')) {
            // Find next Friday
            const daysUntilFriday = (5 - now.getDay() + 7) % 7 || 7;
            dueDate = new Date(now.getTime() + daysUntilFriday * 24 * 60 * 60 * 1000);
          } else if (dueDateLower.includes('next week')) {
            dueDate = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
          }
          // Add more date parsing as needed
        }
        
        const actionItem = {
          id: itemRef.id,
          conversationId: conversationId,
          title: item.title || 'Untitled task',
          assignee: item.assignee || null,
          dueDate: dueDate,
          sourceMsgIds: Array.isArray(item.sourceMsgIds) ? item.sourceMsgIds : [],
          confidence: item.confidence || 0.8,
          completed: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: context.auth.uid,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };
        
        await itemRef.set(actionItem);
        createdItems.push(actionItem);
        
        console.log(`✅ Created action item: ${item.title}`);
      }
      
      console.log(`✅ Action items extracted: ${createdItems.length} items created`);
      console.log(`   Items will appear in ActionItemsView panel on requesting device only`);
      
      return {
        success: true,
        items: createdItems,
        itemCount: createdItems.length
      };
      
    } catch (error: any) {
      console.error('❌ Action item extraction failed:', error);
      throw new functions.https.HttpsError(
        'internal',
        `Failed to extract action items: ${error.message}`
      );
    }
  }
);

