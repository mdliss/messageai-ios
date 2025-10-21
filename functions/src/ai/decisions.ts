/**
 * Detect and log team decisions using OpenAI GPT
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import OpenAI from 'openai';

interface Message {
  id: string;
  senderId: string;
  senderName: string;
  text: string;
  type: 'text' | 'image';
}

/**
 * Detect decisions and create insight
 */
export const detectDecision = functions
  .runWith({
    timeoutSeconds: 60,
    memory: '512MB',
  })
  .firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data() as Message;
    const conversationId = context.params.conversationId;
    
    // Only check text messages
    if (message.type !== 'text') {
      return;
    }
    
    const text = message.text.toLowerCase();
    
    // Pattern matching for decision keywords
    const decisionKeywords = [
      "let's go with",
      "let's use",
      "we'll use",
      "decided",
      "approved",
      "agreed",
      "final decision",
      "confirmed",
      "settling on",
    ];
    
    const hasDecisionKeyword = decisionKeywords.some(keyword => 
      text.includes(keyword)
    );
    
    if (!hasDecisionKeyword) {
      return;
    }
    
    console.log(`📋 Decision detected in message: ${message.id}`);
    
    try {
      const apiKey = functions.config().openai?.key;
      
      if (!apiKey) {
        console.log('ℹ️ OpenAI API key not configured');
        return;
      }
      
      // Fetch recent messages for context
      const messagesRef = admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', 'desc')
        .limit(20);
      
      const messagesSnapshot = await messagesRef.get();
      const recentMessages = messagesSnapshot.docs
        .map(doc => doc.data() as Message)
        .reverse();
      
      const transcript = recentMessages.map(msg => 
        `${msg.senderName}: ${msg.text}`
      ).join('\n');
      
      // Call OpenAI to extract decision
      const openai = new OpenAI({
        apiKey: apiKey,
      });
      
      const response = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        max_tokens: 200,
        temperature: 0.7,
        messages: [{
          role: 'user',
          content: `Extract the decision from this conversation. Be concise and specific. Format: "Decision: [what was decided]". Never use hyphens.\n\nConversation:\n${transcript}`,
        }],
      });
      
      const decision = response.choices[0]?.message?.content || '';
      
      // Store insight
      const insightRef = admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .collection('insights')
        .doc();
      
      const insight = {
        id: insightRef.id,
        conversationId: conversationId,
        type: 'decision',
        content: decision,
        metadata: {
          approvedBy: [message.senderId],
        },
        messageIds: [message.id],
        triggeredBy: message.senderId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        dismissed: false,
      };
      
      await insightRef.set(insight);
      
      console.log(`✅ Decision logged for conversation ${conversationId}`);
      
    } catch (error) {
      console.error('❌ Decision detection failed:', error);
    }
  });

