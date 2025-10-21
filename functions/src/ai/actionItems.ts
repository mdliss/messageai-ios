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
export const extractActionItems = functions.https.onCall(
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
        max_tokens: 500,
        temperature: 0.7,
        messages: [{
          role: 'user',
          content: `Extract action items from this team conversation. Format each as: "Owner: Task (deadline if mentioned)". Only include clear, actionable items. Never use hyphens.\n\nConversation:\n${transcript}`,
        }],
      });
      
      const actionItems = response.choices[0]?.message?.content || '';
      
      // Store insight
      const insightRef = admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .collection('insights')
        .doc();
      
      const insight = {
        id: insightRef.id,
        conversationId: conversationId,
        type: 'action_items',
        content: actionItems,
        metadata: {
          messageCount: messages.length,
        },
        messageIds: messages.map(m => m.id),
        triggeredBy: context.auth.uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        dismissed: false,
      };
      
      await insightRef.set(insight);
      
      console.log(`✅ Action items extracted for conversation ${conversationId}`);
      
      return {
        success: true,
        insight: insight,
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

