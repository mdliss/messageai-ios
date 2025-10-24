/**
 * Advanced AI Feature: Proactive Blocker Detection
 * 
 * Automatically detects when team members are blocked or stuck
 * and alerts managers so they can help quickly.
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

interface BlockerAnalysis {
  isBlocked: boolean;
  description?: string;
  type?: 'explicit' | 'approval' | 'resource' | 'technical' | 'people' | 'time_based';
  severity?: 'critical' | 'high' | 'medium' | 'low';
  suggestedActions?: string[];
  confidence?: number;
}

/**
 * Get conversation context with timestamps for blocker detection
 */
async function getBlockerContext(
  conversationId: string,
  limit: number = 20
): Promise<string> {
  console.log(`📚 fetching conversation context for blocker detection...`);
  
  const messagesRef = admin.firestore()
    .collection('conversations')
    .doc(conversationId)
    .collection('messages')
    .orderBy('createdAt', 'desc')
    .limit(limit);
  
  const messagesSnapshot = await messagesRef.get();
  
  if (messagesSnapshot.empty) {
    return '';
  }
  
  // Format with timestamps to help detect time-based patterns
  const messages = messagesSnapshot.docs
    .map(doc => doc.data() as Message)
    .reverse();
  
  const transcript = messages.map(msg => {
    const timestamp = msg.createdAt.toDate();
    const timeStr = timestamp.toLocaleTimeString('en-US', {
      hour: '2-digit',
      minute: '2-digit'
    });
    
    if (msg.type === 'text') {
      return `[${timeStr}] ${msg.senderName}: ${msg.text}`;
    } else {
      return `[${timeStr}] ${msg.senderName}: [sent an image]`;
    }
  }).join('\n');
  
  return transcript;
}

/**
 * Detect if a message indicates the sender is blocked
 * 
 * Main entry point for blocker detection
 */
export const detectBlocker = functions
  .runWith({
    timeoutSeconds: 15,
    memory: '512MB',
  })
  .https.onCall(async (data, context) => {
    console.log('🔍 detectBlocker called');
    
    // ============================================
    // 1. AUTHENTICATION CHECK
    // ============================================
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'user must be authenticated'
      );
    }
    
    // ============================================
    // 2. VALIDATE PARAMETERS
    // ============================================
    const conversationId = data.conversationId as string;
    const messageId = data.messageId as string;
    
    if (!conversationId || !messageId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'conversationId and messageId are required'
      );
    }
    
    console.log(`🔍 analyzing message ${messageId} for blockers...`);
    
    try {
      // ============================================
      // 3. FETCH MESSAGE
      // ============================================
      const messageDoc = await admin.firestore()
        .collection('conversations').doc(conversationId)
        .collection('messages').doc(messageId)
        .get();
      
      if (!messageDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'message not found');
      }
      
      const message = messageDoc.data() as Message;
      
      // Only analyze text messages
      if (message.type !== 'text') {
        console.log(`⏭️ message is not text, skipping`);
        return { success: true, blocker: null, reason: 'not text message' };
      }
      
      // ============================================
      // 4. FETCH CONTEXT
      // ============================================
      const conversationContext = await getBlockerContext(conversationId, 20);
      
      // ============================================
      // 5. CALL OPENAI FOR ANALYSIS
      // ============================================
      const apiKey = functions.config().openai?.key;
      
      if (!apiKey) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'openai api key not configured'
        );
      }
      
      const openai = new OpenAI({ apiKey });
      
      const prompt = `analyze this message to determine if the sender is blocked or stuck on their work.

conversation context (last 20 messages with timestamps):
${conversationContext}

message to analyze:
"${message.text}" - sent by ${message.senderName}

determine:
1. is this person blocked or stuck? (yes/no)
2. if yes, what specifically are they blocked on? (brief description, 5 to 10 words)
3. blocker type: explicit, approval, resource, technical, people, time_based
4. severity: critical, high, medium, low
5. suggested actions for manager (2 to 3 specific actions, each 5 to 10 words)
6. confidence in this analysis (0.0 to 1.0)

blocker type definitions:
- explicit: person says "i'm blocked on" or "i'm stuck on"
- approval: waiting for someone to approve or review
- resource: missing access, credentials, or tools
- technical: stuck on a bug or technical problem
- people: waiting for specific person to respond or act
- time_based: mentioned issue multiple times over time with no resolution

severity guidelines:
- critical: blocks production/release, multiple people affected, 24+ hours waiting, hard deadline
- high: blocks sprint work, 6+ hours waiting, no response to help request, affects milestones
- medium: blocks individual work, 2 to 4 hours waiting, workarounds possible
- low: minor inconvenience, just mentioned, already being helped

if person is NOT blocked, return: {"isBlocked": false}

if person IS blocked, return json (no markdown, no code fences, no explanation):
{
  "isBlocked": true,
  "description": "brief description here",
  "type": "blocker_type",
  "severity": "severity_level",
  "suggestedActions": [
    "specific action 1",
    "specific action 2"
  ],
  "confidence": 0.90
}`;

      console.log('🤖 calling gpt-4o for blocker analysis...');
      const aiStartTime = Date.now();
      
      const response = await openai.chat.completions.create({
        model: 'gpt-4o',
        temperature: 0.3,
        max_tokens: 500,
        messages: [
          {
            role: 'system',
            content: 'you are an expert at identifying when team members are blocked or stuck. analyze messages to detect blockers accurately. be conservative - only flag real blockers. return only valid json. never use hyphens in responses.'
          },
          {
            role: 'user',
            content: prompt
          }
        ]
      });
      
      const aiTime = Date.now() - aiStartTime;
      console.log(`✅ ai response received in ${aiTime}ms`);
      
      const responseText = response.choices[0]?.message?.content || '{}';
      console.log(`📊 ai response: ${responseText}`);
      
      // ============================================
      // 6. PARSE AI RESPONSE
      // ============================================
      let result: BlockerAnalysis;
      
      try {
        let jsonText = responseText.trim();
        if (jsonText.startsWith('```')) {
          jsonText = jsonText.replace(/```json?\n?/g, '').replace(/```\n?/g, '');
        }
        result = JSON.parse(jsonText);
      } catch (error) {
        console.error('❌ failed to parse ai response:', error);
        throw new functions.https.HttpsError(
          'internal',
          'failed to parse ai response'
        );
      }
      
      // If not a blocker, we're done
      if (!result.isBlocked) {
        console.log('✅ not a blocker, analysis complete');
        return { success: true, blocker: null };
      }
      
      // Only save high confidence blockers
      if (!result.confidence || result.confidence < 0.7) {
        console.log(`⚠️ blocker detected but confidence too low (${result.confidence}), not saving`);
        return { success: true, blocker: null, reason: 'low confidence' };
      }
      
      // ============================================
      // 7. SAVE BLOCKER TO FIRESTORE
      // ============================================
      console.log(`💾 saving blocker (severity: ${result.severity}, confidence: ${result.confidence})...`);
      
      const blockerRef = admin.firestore()
        .collection('conversations').doc(conversationId)
        .collection('blockers').doc();
      
      const blocker = {
        id: blockerRef.id,
        detectedAt: admin.firestore.FieldValue.serverTimestamp(),
        messageId: messageId,
        blockedUserId: message.senderId,
        blockedUserName: message.senderName,
        blockerDescription: result.description || 'blocker detected',
        blockerType: result.type || 'explicit',
        severity: result.severity || 'medium',
        status: 'active',
        suggestedActions: result.suggestedActions || [],
        conversationId: conversationId,
        confidence: result.confidence,
        managerMarkedFalsePositive: false,
        resolvedAt: null,
        resolvedBy: null,
        resolutionNotes: null,
        snoozedUntil: null
      };
      
      await blockerRef.set(blocker);
      console.log(`✅ blocker saved: ${blockerRef.id}`);
      
      // ============================================
      // 8. SEND NOTIFICATIONS (for critical/high only)
      // ============================================
      if (result.severity === 'critical' || result.severity === 'high') {
        console.log(`📲 blocker is ${result.severity}, creating alerts for managers...`);
        
        // Get conversation participants
        const convoDoc = await admin.firestore()
          .collection('conversations').doc(conversationId)
          .get();
        
        if (convoDoc.exists) {
          const conversation = convoDoc.data();
          const participantIds = conversation?.participantIds || [];
          
          // Create blocker alerts for each participant (except the blocked person)
          for (const userId of participantIds) {
            if (userId === message.senderId) continue;
            
            const alertRef = admin.firestore()
              .collection('users').doc(userId)
              .collection('blockerAlerts').doc();
            
            await alertRef.set({
              id: alertRef.id,
              blockerId: blockerRef.id,
              conversationId: conversationId,
              severity: result.severity,
              blockerDescription: result.description || 'blocker detected',
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              read: false,
              dismissed: false
            });
            
            console.log(`✅ alert created for user ${userId}`);
          }
        }
      } else {
        console.log(`ℹ️ blocker is ${result.severity}, no notifications sent (only critical/high get alerts)`);
      }
      
      return {
        success: true,
        blocker: blocker
      };
      
    } catch (error: any) {
      console.error('❌ error in blocker detection:', error);
      throw new functions.https.HttpsError(
        'internal',
        'failed to detect blocker',
        error.message
      );
    }
  });

/**
 * Firestore trigger: Auto-detect blockers on new message creation
 * 
 * Runs keyword filter first before expensive AI call
 */
export const onMessageCreatedCheckBlocker = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data() as Message;
    const conversationId = context.params.conversationId;
    const messageId = context.params.messageId;
    
    console.log(`📨 new message created: ${messageId}`);
    
    // Only check text messages
    if (message.type !== 'text') {
      console.log(`⏭️ message is not text, skipping blocker check`);
      return;
    }
    
    // Fast keyword filter before expensive AI call
    const blockerKeywords = [
      'blocked', 'stuck', 'waiting for', "can't proceed", "can't move forward",
      'need help', 'unable to', "don't have access", "no access",
      'need approval', 'who can', 'need credentials', 'need permission',
      'been trying', 'keeps failing', 'error', 'not working'
    ];
    
    const messageText = message.text.toLowerCase();
    const mightBeBlocker = blockerKeywords.some(keyword =>
      messageText.includes(keyword)
    );
    
    if (!mightBeBlocker) {
      console.log(`⏭️ message doesn't contain blocker keywords, skipping ai analysis`);
      return;
    }
    
    // Potential blocker detected, run AI analysis
    console.log(`🔍 potential blocker detected, running ai analysis...`);
    
    try {
      // Call detectBlocker function (not directly, but via internal logic)
      // Since we're already in a cloud function, we'll duplicate the logic here
      
      const conversationContext = await getBlockerContext(conversationId, 20);
      
      const apiKey = functions.config().openai?.key;
      if (!apiKey) {
        console.error('❌ openai api key not configured');
        return;
      }
      
      const openai = new OpenAI({ apiKey });
      
      const prompt = `analyze this message to determine if the sender is blocked or stuck on their work.

conversation context (last 20 messages with timestamps):
${conversationContext}

message to analyze:
"${message.text}" - sent by ${message.senderName}

determine:
1. is this person blocked or stuck? (yes/no)
2. if yes, what specifically are they blocked on? (brief description, 5 to 10 words)
3. blocker type: explicit, approval, resource, technical, people, time_based
4. severity: critical, high, medium, low
5. suggested actions for manager (2 to 3 specific actions, each 5 to 10 words)
6. confidence in this analysis (0.0 to 1.0)

severity guidelines:
- critical: blocks production/release, multiple people affected, 24+ hours waiting
- high: blocks sprint work, 6+ hours waiting, no response to help request
- medium: blocks individual work, 2 to 4 hours waiting, workarounds possible
- low: minor inconvenience, just mentioned, already being helped

if person is NOT blocked, return: {"isBlocked": false}

if person IS blocked, return json (no markdown, no explanation):
{
  "isBlocked": true,
  "description": "brief description",
  "type": "blocker_type",
  "severity": "severity_level",
  "suggestedActions": ["action 1", "action 2"],
  "confidence": 0.90
}`;

      const response = await openai.chat.completions.create({
        model: 'gpt-4o',
        temperature: 0.3,
        max_tokens: 500,
        messages: [
          {
            role: 'system',
            content: 'you are an expert at identifying when team members are blocked. analyze messages to detect blockers accurately. be conservative, only flag real blockers. return only valid json. never use hyphens.'
          },
          {
            role: 'user',
            content: prompt
          }
        ]
      });
      
      const responseText = response.choices[0]?.message?.content || '{}';
      console.log(`📊 ai blocker analysis: ${responseText}`);
      
      // Parse response
      let result: BlockerAnalysis;
      try {
        let jsonText = responseText.trim();
        if (jsonText.startsWith('```')) {
          jsonText = jsonText.replace(/```json?\n?/g, '').replace(/```\n?/g, '');
        }
        result = JSON.parse(jsonText);
      } catch (error) {
        console.error('❌ failed to parse ai response:', error);
        return;
      }
      
      // If not a blocker, we're done
      if (!result.isBlocked) {
        console.log('✅ not a blocker');
        return;
      }
      
      // Only save high confidence blockers
      if (!result.confidence || result.confidence < 0.7) {
        console.log(`⚠️ confidence too low (${result.confidence}), not saving`);
        return;
      }
      
      // Save blocker
      const blockerRef = admin.firestore()
        .collection('conversations').doc(conversationId)
        .collection('blockers').doc();
      
      const blocker = {
        id: blockerRef.id,
        detectedAt: admin.firestore.FieldValue.serverTimestamp(),
        messageId: messageId,
        blockedUserId: message.senderId,
        blockedUserName: message.senderName,
        blockerDescription: result.description || 'blocker detected',
        blockerType: result.type || 'explicit',
        severity: result.severity || 'medium',
        status: 'active',
        suggestedActions: result.suggestedActions || [],
        conversationId: conversationId,
        confidence: result.confidence,
        managerMarkedFalsePositive: false,
        resolvedAt: null,
        resolvedBy: null,
        resolutionNotes: null,
        snoozedUntil: null
      };
      
      await blockerRef.set(blocker);
      console.log(`✅ blocker saved: ${blockerRef.id}`);
      
      // Send notifications for critical/high severity
      if (result.severity === 'critical' || result.severity === 'high') {
        console.log(`📲 creating alerts for ${result.severity} blocker...`);
        
        const convoDoc = await admin.firestore()
          .collection('conversations').doc(conversationId)
          .get();
        
        if (convoDoc.exists) {
          const conversation = convoDoc.data();
          const participantIds = conversation?.participantIds || [];
          
          for (const userId of participantIds) {
            if (userId === message.senderId) continue;
            
            const alertRef = admin.firestore()
              .collection('users').doc(userId)
              .collection('blockerAlerts').doc();
            
            await alertRef.set({
              id: alertRef.id,
              blockerId: blockerRef.id,
              conversationId: conversationId,
              severity: result.severity,
              blockerDescription: result.description || 'blocker detected',
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              read: false,
              dismissed: false
            });
            
            console.log(`✅ alert created for user ${userId}`);
          }
        }
      }
      
    } catch (error) {
      console.error('❌ blocker detection error:', error);
      // Don't throw - detection failure shouldn't break message delivery
    }
  });
