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
      
      console.log(`📨 Fetched ${messagesSnapshot.size} messages from conversation`);
      
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
      
      console.log(`📝 Transcript prepared with ${messages.length} messages`);
      console.log(`📋 First 500 chars of transcript: ${transcript.substring(0, 500)}`);
      
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
      
      console.log(`🤖 Calling GPT-4o for action item extraction...`);
      
      const response = await openai.chat.completions.create({
        model: 'gpt-4o',
        max_tokens: 1500,
        temperature: 0.3,
        messages: [{
          role: 'system',
          content: 'You are an expert at extracting actionable tasks from conversations. Your job is to identify concrete tasks that require someone to do something specific. Be generous in your extraction - when in doubt, extract it as an action item. Return ONLY valid JSON array, no markdown, no explanation. Never use hyphens.',
        }, {
          role: 'user',
          content: `Extract ALL action items from this conversation.

An ACTION ITEM is ANY message that indicates:
✅ Someone needs to do something
✅ A task is being assigned or accepted
✅ A commitment is being made
✅ An imperative or command is given
✅ A requirement is stated

ALWAYS EXTRACT:
1. Direct assignments: "Bob, review PR #234 by Friday"
2. Personal commitments: "I'll send the report tomorrow"
3. Commands and imperatives: "You must finish the assignment" or "Complete the code review ASAP"
4. Requirements: "Make sure to attend the standup"
5. Team actions: "We need to schedule the meeting this week"
6. Collective tasks: "Someone needs to review the document"
7. Urgent requests: "URGENT: Production is down"

NEVER EXTRACT:
- Pure questions with no commitment: "Should we meet?"
- Simple acknowledgments: "ok" or "sounds good"
- Pure information: "FYI the meeting moved"

IMPORTANT: When in doubt, EXTRACT IT. Better to have too many than miss important tasks.

Return ONLY a JSON array (no markdown, no code fences, no explanation):
[
  {
    "title": "Clear description of what needs to be done",
    "assignee": "Name if mentioned or null",
    "dueDate": "Natural language like friday, tomorrow, next week, or null",
    "confidence": 0.85,
    "sourceMsgIds": []
  }
]

If no action items found, return: []

Conversation:
${transcript}

Return ONLY the JSON array:`,
        }],
      });
      
      const responseText = response.choices[0]?.message?.content || '[]';
      
      console.log(`🤖 GPT-4o raw response:`);
      console.log(responseText);
      console.log(`📏 Response length: ${responseText.length} characters`);
      
      // Parse JSON response
      let parsedItems: any[] = [];
      try {
        // Try to extract JSON from response
        // Handle markdown code fences: ```json ... ```
        let jsonText = responseText.trim();
        
        // Remove markdown code fences if present
        jsonText = jsonText.replace(/^```(?:json)?\s*\n?/i, '');
        jsonText = jsonText.replace(/\n?```\s*$/i, '');
        jsonText = jsonText.trim();
        
        // If still not starting with [, try to find the array
        if (!jsonText.startsWith('[')) {
          const jsonMatch = jsonText.match(/\[[\s\S]*\]/);
          if (jsonMatch) {
            jsonText = jsonMatch[0];
          }
        }
        
        console.log(`🔍 Attempting to parse JSON...`);
        console.log(`📋 JSON text to parse: ${jsonText.substring(0, 300)}`);
        
        parsedItems = JSON.parse(jsonText);
        
        console.log(`✅ Successfully parsed ${parsedItems.length} items from GPT response`);
        
      } catch (error: any) {
        console.error('❌ JSON parsing failed!');
        console.error(`   Error: ${error.message}`);
        console.error(`   Raw response was: ${responseText}`);
        
        // Don't fail silently - throw error so we know something is wrong
        throw new functions.https.HttpsError(
          'internal',
          `Failed to parse AI response as JSON: ${error.message}. Raw response: ${responseText.substring(0, 200)}`
        );
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
      
      console.log(`💾 Creating ${parsedItems.length} action item documents in Firestore...`);
      
      const createdItems: any[] = [];
      
      for (let i = 0; i < parsedItems.length; i++) {
        const item = parsedItems[i];
        console.log(`📝 Processing item ${i + 1}/${parsedItems.length}: "${item.title}"`);
        
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
        
        console.log(`   ➡️ Title: "${actionItem.title}"`);
        console.log(`   ➡️ Assignee: ${actionItem.assignee || 'none'}`);
        console.log(`   ➡️ Due Date: ${dueDate ? dueDate.toISOString() : 'none'}`);
        console.log(`   ➡️ Confidence: ${actionItem.confidence}`);
        
        await itemRef.set(actionItem);
        createdItems.push(actionItem);
        
        console.log(`   ✅ Created in Firestore with ID: ${itemRef.id}`);
      }
      
      console.log(`🎉 Action items extraction complete!`);
      console.log(`   Total items created: ${createdItems.length}`);
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

