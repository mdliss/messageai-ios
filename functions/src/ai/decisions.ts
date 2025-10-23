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
    
    // CRITICAL FIX: Skip AI assistant messages to prevent auto-decisions from polls
    // AI assistant posts messages with "option 1, option 2, option 3" which would trigger decision detection
    if (message.senderId === 'ai_assistant') {
      console.log(`ℹ️ Skipping decision detection for AI assistant message`);
      return;
    }
    
    const text = message.text.toLowerCase();
    
    // Pattern matching for decision keywords
    // CRITICAL: These should be FINAL DECISION phrases only, not voting phrases
    // Removed: "option 1/2/3", "works for me", "that works", "sounds good" (those are votes, not decisions)
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
      "greenlit",
      "moving forward with",
    ];
    
    const hasDecisionKeyword = decisionKeywords.some(keyword => 
      text.includes(keyword)
    );
    
    if (!hasDecisionKeyword) {
      return;
    }
    
    console.log(`📋 Decision keyword detected in message: ${message.id}`);
    
    // Check if this is a response to scheduling assistant
    const messagesRef = admin.firestore()
      .collection('conversations')
      .doc(conversationId)
      .collection('messages')
      .orderBy('createdAt', 'desc')
      .limit(10);
    
    const messagesSnapshot = await messagesRef.get();
    const recentMessages = messagesSnapshot.docs.map(doc => doc.data() as Message);
    
    // Look for scheduling assistant message in recent history
    const hasSchedulingAssistant = recentMessages.some(msg => 
      msg.senderId === 'ai_assistant' && 
      msg.text.includes('scheduling assistant')
    );
    
    // If responding to scheduling assistant, treat as meeting time decision
    const isSchedulingDecision = hasSchedulingAssistant && 
      (text.includes('option') || text.includes('works for me') || text.includes('that works'));
    
    console.log(`📋 Decision detected in message: ${message.id}, isSchedulingDecision: ${isSchedulingDecision}`);
    
    try {
      const apiKey = functions.config().openai?.key;
      
      if (!apiKey) {
        console.log('ℹ️ OpenAI API key not configured');
        return;
      }
      
      // Fetch all recent messages for full context (already fetched above, reuse)
      const allRecentMessages = recentMessages.reverse();
      
      const transcript = allRecentMessages.map(msg => 
        `${msg.senderName}: ${msg.text}`
      ).join('\n');
      
      // Call OpenAI to extract decision
      const openai = new OpenAI({
        apiKey: apiKey,
      });
      
      const systemPrompt = isSchedulingDecision 
        ? 'You are an intelligent assistant helping remote teams track meeting time decisions. When someone selects a meeting time option, extract and format it as a clear decision. Never use hyphens.'
        : 'You are an intelligent assistant helping remote teams track important decisions that often get buried in chat history. Extract clear, specific decisions so teams never have to search through hundreds of messages. Never use hyphens.';
      
      const userPrompt = isSchedulingDecision
        ? `Extract the meeting time decision from this conversation. Someone has selected a meeting time option. Format the decision clearly with the chosen time.

Format as: "Meeting scheduled for [specific time with all time zones mentioned]"

Never use hyphens.

Conversation:
${transcript}`
        : `Extract the key decision from this remote team conversation. Be concise and specific about what was decided and any relevant context.

Format as a clear statement without the word "Decision:" prefix. Just state what was decided.

Never use hyphens.

Conversation:
${transcript}`;
      
      const response = await openai.chat.completions.create({
        model: 'gpt-4o',
        max_tokens: 200,
        temperature: 0.7,
        messages: [{
          role: 'system',
          content: systemPrompt,
        }, {
          role: 'user',
          content: userPrompt,
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

