/**
 * Advanced AI Feature: Smart Response Suggestions
 * 
 * Generates AI-powered response suggestions for managers to save time
 * and maintain communication quality.
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
  createdAt: admin.firestore.Timestamp;
}

interface ResponseSuggestionOption {
  id: string;
  text: string;
  type: 'approve' | 'decline' | 'conditional' | 'delegate';
  reasoning: string;
  confidence: number;
}

/**
 * Get conversation context for AI prompt
 * Fetches recent messages and formats as transcript
 */
async function getConversationContext(
  conversationId: string,
  limit: number = 20
): Promise<string> {
  console.log(`📚 fetching last ${limit} messages for context...`);
  
  const messagesRef = admin.firestore()
    .collection('conversations')
    .doc(conversationId)
    .collection('messages')
    .orderBy('createdAt', 'desc')
    .limit(limit);
  
  const messagesSnapshot = await messagesRef.get();
  
  console.log(`📨 fetched ${messagesSnapshot.size} messages`);
  
  if (messagesSnapshot.empty) {
    return '';
  }
  
  // Format as transcript (reverse to chronological order)
  const messages = messagesSnapshot.docs
    .map(doc => doc.data() as Message)
    .reverse();
  
  const transcript = messages.map(msg => {
    if (msg.type === 'text') {
      return `${msg.senderName}: ${msg.text}`;
    } else {
      return `${msg.senderName}: [sent an image]`;
    }
  }).join('\n');
  
  return transcript;
}

/**
 * Get manager's communication style examples
 * Fetches recent responses from manager in other conversations
 */
async function getManagerStyleExamples(
  currentUserId: string,
  limit: number = 10
): Promise<string> {
  console.log(`👔 fetching manager's recent responses for style analysis...`);
  
  try {
    // Query messages sent by current user across all conversations
    const recentMessagesQuery = admin.firestore()
      .collectionGroup('messages')
      .where('senderId', '==', currentUserId)
      .where('type', '==', 'text')
      .orderBy('createdAt', 'desc')
      .limit(limit);
    
    const messagesSnapshot = await recentMessagesQuery.get();
    
    console.log(`📝 found ${messagesSnapshot.size} recent manager messages`);
    
    if (messagesSnapshot.empty) {
      return 'no previous messages available for style analysis';
    }
    
    // Format as examples
    const examples = messagesSnapshot.docs
      .map(doc => {
        const msg = doc.data() as Message;
        return `"${msg.text}"`;
      })
      .join('\n');
    
    return examples;
  } catch (error) {
    console.warn('⚠️ failed to fetch manager style examples:', error);
    return 'style analysis unavailable';
  }
}

/**
 * Generate smart response suggestions for a message
 * 
 * @param conversationId - ID of the conversation
 * @param messageId - ID of the message requiring response
 * @param currentUserId - ID of the manager requesting suggestions
 * 
 * @returns Object containing array of suggestion options
 */
export const generateResponseSuggestions = functions
  .runWith({
    timeoutSeconds: 10,
    memory: '512MB',
  })
  .https.onCall(async (data, context) => {
    console.log('🎯 generateResponseSuggestions called');
    
    // ============================================
    // 1. AUTHENTICATION CHECK
    // ============================================
    if (!context.auth) {
      console.error('❌ unauthenticated request');
      throw new functions.https.HttpsError(
        'unauthenticated',
        'user must be authenticated to generate suggestions'
      );
    }
    
    const currentUserId = context.auth.uid;
    console.log(`✅ authenticated user: ${currentUserId}`);
    
    // ============================================
    // 2. VALIDATE PARAMETERS
    // ============================================
    const conversationId = data.conversationId as string;
    const messageId = data.messageId as string;
    
    if (!conversationId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'conversationId is required'
      );
    }
    
    if (!messageId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'messageId is required'
      );
    }
    
    console.log(`📨 generating suggestions for message ${messageId} in conversation ${conversationId}`);
    
    try {
      // ============================================
      // 3. CHECK FOR CACHED SUGGESTIONS
      // ============================================
      console.log('🔍 checking for cached suggestions...');
      
      const messageRef = admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId);
      
      const messageDoc = await messageRef.get();
      
      if (!messageDoc.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'message not found'
        );
      }
      
      const messageData = messageDoc.data();
      
      if (!messageData) {
        throw new functions.https.HttpsError('not-found', 'message data not found');
      }
      
      // Check if we have cached suggestions that haven't expired
      if (messageData.responseSuggestions) {
        const cache = messageData.responseSuggestions;
        const expiresAt = cache.expiresAt?.toDate();
        
        if (expiresAt && expiresAt > new Date()) {
          console.log('✅ returning cached suggestions (not expired)');
          return {
            success: true,
            cached: true,
            options: cache.options,
            generatedAt: cache.generatedAt
          };
        } else {
          console.log('⏰ cached suggestions expired, regenerating...');
        }
      }
      
      // ============================================
      // 4. FETCH CONVERSATION CONTEXT (Task 5)
      // ============================================
      console.log('📚 gathering conversation context...');
      const startTime = Date.now();
      
      const conversationHistory = await getConversationContext(conversationId, 15);
      const managerStyleExamples = await getManagerStyleExamples(currentUserId, 10);
      
      const contextTime = Date.now() - startTime;
      console.log(`✅ context gathered in ${contextTime}ms`);
      
      // ============================================
      // 5. BUILD AI PROMPT (Task 4)
      // ============================================
      console.log('🎨 building ai prompt...');
      
      const systemPrompt = `you are helping a busy manager respond to team messages efficiently and professionally.

your job is to generate 3 to 4 high quality response options that:
1. match the manager's communication style (examples provided below)
2. are contextually appropriate to the specific situation
3. cover different response types: approve, decline, conditional (ask more info), delegate (defer decision)
4. are professional, clear, and actionable
5. consider the full conversation context and history

important:
- never use hyphens in responses
- write in lowercase unless proper nouns
- be direct and concise
- match manager's tone (formal vs casual)
- provide complete, actionable responses
- return only valid json array, no markdown, no code fences, no explanation`;

      const userPrompt = `conversation context (recent messages):
${conversationHistory}

message requiring response:
"${messageData.text}" - from ${messageData.senderName}

manager's typical communication style (recent messages):
${managerStyleExamples}

generate 3 to 4 response options. for each option provide:
- text: the complete response the manager can send (full sentence, actionable)
- type: 'approve' | 'decline' | 'conditional' | 'delegate'
- reasoning: one sentence explaining why this suggestion fits this situation

return only json array:
[
  {
    "text": "complete suggested response text here",
    "type": "approve",
    "reasoning": "brief explanation of why this fits"
  }
]`;

      // ============================================
      // 6. CALL OPENAI API (Task 6)
      // ============================================
      const apiKey = functions.config().openai?.key;
      
      if (!apiKey) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'openai api key not configured'
        );
      }
      
      const openai = new OpenAI({ apiKey });
      
      console.log('🤖 calling gpt-4o for response suggestions...');
      const aiStartTime = Date.now();
      
      const response = await openai.chat.completions.create({
        model: 'gpt-4o',
        temperature: 0.7,  // creative but consistent
        max_tokens: 800,
        messages: [
          {
            role: 'system',
            content: systemPrompt
          },
          {
            role: 'user',
            content: userPrompt
          }
        ]
      });
      
      const aiTime = Date.now() - aiStartTime;
      console.log(`✅ gpt-4o response received in ${aiTime}ms`);
      
      const responseText = response.choices[0]?.message?.content || '[]';
      console.log(`📊 ai response: ${responseText.substring(0, 200)}...`);
      
      // ============================================
      // 7. PARSE AI RESPONSE
      // ============================================
      console.log('🔍 parsing ai response...');
      
      let suggestions: ResponseSuggestionOption[] = [];
      
      try {
        // Handle potential markdown code fences
        let jsonText = responseText.trim();
        if (jsonText.startsWith('```')) {
          jsonText = jsonText.replace(/```json?\n?/g, '').replace(/```\n?/g, '');
        }
        
        const parsed = JSON.parse(jsonText);
        
        if (!Array.isArray(parsed)) {
          throw new Error('ai response is not an array');
        }
        
        // Add IDs to suggestions
        suggestions = parsed.map((item: any, index: number) => ({
          id: `sug_${Date.now()}_${index}`,
          text: item.text || '',
          type: item.type || 'conditional',
          reasoning: item.reasoning || '',
          confidence: item.confidence || 0.8
        }));
        
        console.log(`✅ parsed ${suggestions.length} suggestions`);
        
      } catch (error) {
        console.error('❌ failed to parse ai response as json:', error);
        throw new functions.https.HttpsError(
          'internal',
          'failed to parse ai response'
        );
      }
      
      // Validate we have 3-4 suggestions
      if (suggestions.length < 2) {
        console.warn(`⚠️ only ${suggestions.length} suggestions generated, expected 3-4`);
      }
      
      // ============================================
      // 8. CACHE SUGGESTIONS IN FIRESTORE (Task 7)
      // ============================================
      console.log('💾 caching suggestions in firestore...');
      
      const suggestionsCache = {
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: new Date(Date.now() + 5 * 60 * 1000), // 5 minutes
        options: suggestions
      };
      
      await messageRef.update({
        responseSuggestions: suggestionsCache
      });
      
      console.log('✅ suggestions cached successfully');
      
      // ============================================
      // 9. TRACK THAT SUGGESTIONS WERE SHOWN
      // ============================================
      await messageRef.update({
        suggestionFeedback: {
          wasShown: true,
          wasUsed: false,
          wasEdited: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        }
      });
      
      const totalTime = Date.now() - startTime;
      console.log(`✅ total execution time: ${totalTime}ms`);
      
      return {
        success: true,
        cached: false,
        options: suggestions,
        generatedAt: new Date(),
        executionTimeMs: totalTime
      };
      
    } catch (error: any) {
      console.error('❌ error generating suggestions:', error);
      
      // Don't expose internal errors to client
      throw new functions.https.HttpsError(
        'internal',
        'failed to generate suggestions',
        error.message
      );
    }
  });

