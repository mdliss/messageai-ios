/**
 * Proactive assistant for detecting scheduling needs using OpenAI GPT
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import OpenAI from 'openai';

interface Message {
  id: string;
  senderName: string;
  text: string;
  type: 'text' | 'image';
}

/**
 * Detect scheduling needs and offer help
 */
export const detectProactiveSuggestions = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data() as Message;
    const conversationId = context.params.conversationId;
    
    // Only check text messages
    if (message.type !== 'text') {
      return;
    }
    
    const text = message.text.toLowerCase();
    
    // Pattern matching for scheduling keywords
    const schedulingKeywords = [
      'when can',
      'what time',
      'schedule',
      'meeting',
      'available',
      'free time',
      'book',
      'calendar',
      'coordinate',
    ];
    
    const hasSchedulingKeyword = schedulingKeywords.some(keyword => 
      text.includes(keyword)
    );
    
    if (!hasSchedulingKeyword) {
      return;
    }
    
    console.log(`📅 Scheduling language detected in message: ${message.id}`);
    
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
      
      // Call OpenAI to assess scheduling need
      const openai = new OpenAI({
        apiKey: apiKey,
      });
      
      const response = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        max_tokens: 100,
        temperature: 0.7,
        messages: [{
          role: 'user',
          content: `Does this conversation indicate a scheduling need? Answer with confidence level (0-100) and brief reason. Format: "Confidence: [number]\nReason: [brief explanation]"\n\nConversation:\n${transcript}`,
        }],
      });
      
      const analysisText = response.choices[0]?.message?.content || '';
      
      // Parse confidence
      const confidenceMatch = analysisText.match(/confidence:\s*(\d+)/i);
      const confidence = confidenceMatch ? parseInt(confidenceMatch[1]) : 0;
      
      if (confidence > 80) {
        // Create suggestion insight
        const insightRef = admin.firestore()
          .collection('conversations')
          .doc(conversationId)
          .collection('insights')
          .doc();
        
        const insight = {
          id: insightRef.id,
          conversationId: conversationId,
          type: 'suggestion',
          content: 'Would you like me to help find a time that works for everyone?',
          metadata: {
            action: 'scheduling_help',
            confidence: confidence / 100,
          },
          messageIds: [message.id],
          triggeredBy: 'system',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          dismissed: false,
        };
        
        await insightRef.set(insight);
        
        console.log(`✅ Scheduling suggestion created (confidence: ${confidence}%)`);
      } else {
        console.log(`ℹ️ Confidence too low for suggestion: ${confidence}%`);
      }
      
    } catch (error) {
      console.error('❌ Proactive detection failed:', error);
    }
  });

