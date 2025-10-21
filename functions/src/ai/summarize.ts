/**
 * Thread summarization using OpenAI GPT
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
 * Summarize conversation in 3 bullet points
 */
export const summarizeConversation = functions.https.onCall(
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
    
    console.log(`🤖 Summarizing conversation: ${conversationId}`);
    
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
          'No messages to summarize'
        );
      }
      
      // Format messages as transcript
      const messages = messagesSnapshot.docs
        .map(doc => doc.data() as Message)
        .reverse(); // Chronological order
      
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
          content: `Summarize this team conversation in exactly 3 concise bullet points. Each bullet should be one sentence and capture key information, decisions, or action items. Never use hyphens - write "non profit" not "non-profit".\n\nConversation:\n${transcript}`,
        }],
      });
      
      const summary = response.choices[0]?.message?.content || '';
      
      // Store insight in Firestore
      const insightRef = admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .collection('insights')
        .doc();
      
      const insight = {
        id: insightRef.id,
        conversationId: conversationId,
        type: 'summary',
        content: summary,
        metadata: {
          bulletPoints: 3,
          messageCount: messages.length,
        },
        messageIds: messages.map(m => m.id),
        triggeredBy: context.auth.uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        dismissed: false,
      };
      
      await insightRef.set(insight);
      
      console.log(`✅ Summary created for conversation ${conversationId}`);
      
      return {
        success: true,
        insight: insight,
      };
      
    } catch (error: any) {
      console.error('❌ Summarization failed:', error);
      throw new functions.https.HttpsError(
        'internal',
        `Failed to summarize: ${error.message}`
      );
    }
  }
);

