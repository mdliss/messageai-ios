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
        max_tokens: 800,
        temperature: 0.7,
        messages: [{
          role: 'system',
          content: 'You are an intelligent assistant helping remote teams track tasks mentioned in conversations. Extract clear, actionable items with owners and deadlines. Return as JSON array. Never use hyphens. Be specific.',
        }, {
          role: 'user',
          content: `Extract action items from this remote team conversation. For each clear, actionable item, return JSON format:

[
  {
    "title": "Task description",
    "assignee": "Person name or null if not mentioned",
    "dueDate": "Natural language date like 'friday', 'tomorrow', 'next week', or null",
    "confidence": 0.8,
    "sourceMsgIds": ["array of relevant message indices"]
  }
]

Focus on:
- Commitments people made ("I'll do X")
- Tasks explicitly assigned ("Bob, can you...")
- Deadlines mentioned ("by Friday", "EOD")
- Follow ups needed

Return only the JSON array. If no action items exist, return empty array []. Never use hyphens.

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
      
      const actionItemsText = parsedItems.length > 0
        ? parsedItems.map((item: any, idx: number) => 
            `• ${item.assignee || 'Someone'}: ${item.title}${item.dueDate ? ` (${item.dueDate})` : ''}`
          ).join('\n')
        : 'No clear action items found in this conversation.';
      
      // Store insight for display in popup
      const insightRef = admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .collection('insights')
        .doc();
      
      const insight = {
        id: insightRef.id,
        conversationId: conversationId,
        type: 'action_items',
        content: actionItemsText,
        metadata: {
          messageCount: messages.length,
          itemCount: parsedItems.length,
        },
        messageIds: messages.map(m => m.id),
        triggeredBy: context.auth.uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        dismissed: false,
      };
      
      await insightRef.set(insight);
      
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
      
      return {
        success: true,
        insight: insight,
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

