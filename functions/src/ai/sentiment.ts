/**
 * Advanced AI Feature: Team Sentiment Analysis
 * 
 * Analyzes emotional tone and sentiment of messages to help managers
 * spot morale issues, stress, and team dynamics problems early.
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

interface SentimentAnalysis {
  score: number;  // -1.0 to 1.0
  emotions: string[];
  confidence: number;
  reasoning: string;
}

/**
 * Get sentiment analysis context
 */
async function getSentimentContext(
  conversationId: string,
  limit: number = 10
): Promise<string> {
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
 * Analyze sentiment of a message
 * 
 * Main sentiment analysis function
 */
export const analyzeSentiment = functions
  .runWith({
    timeoutSeconds: 10,
    memory: '512MB',
  })
  .https.onCall(async (data, context) => {
    console.log('😊 analyzeSentiment called');
    
    const conversationId = data.conversationId as string;
    const messageId = data.messageId as string;
    
    if (!conversationId || !messageId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'conversationId and messageId are required'
      );
    }
    
    console.log(`😊 analyzing sentiment for message ${messageId}...`);
    
    try {
      // ============================================
      // 1. FETCH MESSAGE
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
        console.log(`⏭️ message is not text, skipping sentiment analysis`);
        return { success: true, sentiment: null, reason: 'not text message' };
      }
      
      // Check if already analyzed
      if (messageDoc.data()?.sentimentScore !== undefined) {
        console.log(`✅ message already has sentiment score, skipping`);
        return {
          success: true,
          sentiment: messageDoc.data()?.sentimentAnalysis,
          reason: 'already analyzed'
        };
      }
      
      // ============================================
      // 2. FETCH CONTEXT
      // ============================================
      const conversationContext = await getSentimentContext(conversationId, 10);
      
      // ============================================
      // 3. CALL OPENAI
      // ============================================
      const apiKey = functions.config().openai?.key;
      if (!apiKey) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'openai api key not configured'
        );
      }
      
      const openai = new OpenAI({ apiKey });
      
      const prompt = `analyze the sentiment and emotional tone of this message.

conversation context (recent messages for understanding tone):
${conversationContext}

message to analyze:
"${message.text}" - sent by ${message.senderName}

analyze:
1. sentiment score: -1.0 (very negative) to +1.0 (very positive), 0 is neutral
2. specific emotions present: frustrated, excited, stressed, confused, happy, worried, angry, enthusiastic, etc
3. confidence in this analysis: 0.0 to 1.0
4. brief reasoning: one sentence explaining the score

context is important:
- "working on this over the weekend" could be positive (excited) or negative (overwhelmed)
- consider surrounding messages to understand true sentiment
- distinguish sarcasm ("oh great, another meeting" is negative sarcasm)
- professional neutral statements should score near 0
- emojis provide strong sentiment signals

return json (no markdown, no code fences, no explanation):
{
  "score": 0.7,
  "emotions": ["excited", "enthusiastic"],
  "confidence": 0.85,
  "reasoning": "expresses enthusiasm and positive energy about the work"
}`;

      console.log('🤖 calling gpt-4o for sentiment analysis...');
      
      const response = await openai.chat.completions.create({
        model: 'gpt-4o',
        temperature: 0.2,  // consistent analysis
        max_tokens: 300,
        messages: [
          {
            role: 'system',
            content: 'you are an expert at analyzing emotional tone and sentiment in workplace messages. be accurate and context aware. consider surrounding conversation for better understanding. return only valid json. never use hyphens.'
          },
          {
            role: 'user',
            content: prompt
          }
        ]
      });
      
      const responseText = response.choices[0]?.message?.content || '{}';
      console.log(`📊 ai sentiment response: ${responseText}`);
      
      // ============================================
      // 4. PARSE AI RESPONSE
      // ============================================
      let result: SentimentAnalysis;
      
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
      
      // Validate score range
      if (result.score < -1.0 || result.score > 1.0) {
        console.warn(`⚠️ invalid sentiment score: ${result.score}, clamping to range`);
        result.score = Math.max(-1.0, Math.min(1.0, result.score));
      }
      
      // Only save if confidence is reasonable
      if (result.confidence < 0.5) {
        console.log(`⚠️ confidence too low (${result.confidence}), not saving sentiment`);
        return { success: true, sentiment: null, reason: 'low confidence' };
      }
      
      // ============================================
      // 5. SAVE SENTIMENT TO MESSAGE
      // ============================================
      console.log(`💾 saving sentiment (score: ${result.score}, confidence: ${result.confidence})...`);
      
      const sentimentAnalysis = {
        score: result.score,
        emotions: result.emotions || [],
        confidence: result.confidence,
        analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
        reasoning: result.reasoning || ''
      };
      
      await messageDoc.ref.update({
        sentimentScore: result.score,
        sentimentAnalysis: sentimentAnalysis
      });
      
      console.log(`✅ sentiment saved to message`);
      
      return {
        success: true,
        sentiment: {
          score: result.score,
          emotions: result.emotions,
          confidence: result.confidence,
          reasoning: result.reasoning
        }
      };
      
    } catch (error: any) {
      console.error('❌ sentiment analysis error:', error);
      throw new functions.https.HttpsError(
        'internal',
        'failed to analyze sentiment',
        error.message
      );
    }
  });

/**
 * Firestore trigger: Auto-analyze sentiment on new text messages
 */
export const onMessageCreatedAnalyzeSentiment = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data() as Message;
    
    // Only analyze text messages
    if (message.type !== 'text') {
      console.log(`⏭️ message is not text, skipping sentiment analysis`);
      return;
    }
    
    console.log(`😊 new text message, analyzing sentiment...`);
    
    try {
      // Call sentiment analysis
      // Note: In production, consider using the internal logic here instead of calling the callable function
      // to avoid unnecessary overhead
      
      const conversationId = context.params.conversationId;
      
      // Get context
      const conversationContext = await getSentimentContext(conversationId, 10);
      
      // Call OpenAI
      const apiKey = functions.config().openai?.key;
      if (!apiKey) {
        console.error('❌ openai api key not configured');
        return;
      }
      
      const openai = new OpenAI({ apiKey });
      
      const prompt = `analyze the sentiment and emotional tone of this message.

conversation context (recent messages):
${conversationContext}

message to analyze:
"${message.text}" - sent by ${message.senderName}

analyze:
1. sentiment score: -1.0 (very negative) to +1.0 (very positive), 0 is neutral
2. specific emotions: frustrated, excited, stressed, confused, happy, worried, etc
3. confidence: 0.0 to 1.0
4. brief reasoning: one sentence

return json (no markdown):
{
  "score": 0.5,
  "emotions": ["excited"],
  "confidence": 0.85,
  "reasoning": "shows enthusiasm"
}`;

      const response = await openai.chat.completions.create({
        model: 'gpt-4o',
        temperature: 0.2,
        max_tokens: 300,
        messages: [
          {
            role: 'system',
            content: 'analyze emotional tone and sentiment accurately. consider context. return only valid json. never use hyphens.'
          },
          {
            role: 'user',
            content: prompt
          }
        ]
      });
      
      const responseText = response.choices[0]?.message?.content || '{}';
      console.log(`📊 sentiment: ${responseText}`);
      
      // Parse response
      let result: SentimentAnalysis;
      try {
        let jsonText = responseText.trim();
        if (jsonText.startsWith('```')) {
          jsonText = jsonText.replace(/```json?\n?/g, '').replace(/```\n?/g, '');
        }
        result = JSON.parse(jsonText);
      } catch (error) {
        console.error('❌ failed to parse:', error);
        return;
      }
      
      // Validate and save
      if (result.confidence && result.confidence >= 0.5) {
        result.score = Math.max(-1.0, Math.min(1.0, result.score));
        
        await snap.ref.update({
          sentimentScore: result.score,
          sentimentAnalysis: {
            score: result.score,
            emotions: result.emotions || [],
            confidence: result.confidence,
            analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
            reasoning: result.reasoning || ''
          }
        });
        
        console.log(`✅ sentiment saved: ${result.score}`);
      }
      
    } catch (error) {
      console.error('❌ sentiment analysis failed:', error);
      // Don't throw - analysis failure shouldn't break message delivery
    }
  });

/**
 * Scheduled function: Calculate sentiment aggregates
 * 
 * Runs hourly to calculate daily and weekly sentiment scores
 */
export const calculateSentimentAggregates = functions.pubsub
  .schedule('every 1 hours')
  .timeZone('America/Los_Angeles')
  .onRun(async (context) => {
    console.log('🔄 calculating sentiment aggregates...');
    
    const now = new Date();
    const todayStr = now.toISOString().split('T')[0]; // yyyy-mm-dd
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    
    try {
      // ============================================
      // 1. CALCULATE USER DAILY AGGREGATES
      // ============================================
      console.log('📊 calculating user daily aggregates...');
      
      // Get all users
      const usersSnapshot = await admin.firestore().collection('users').get();
      console.log(`👥 found ${usersSnapshot.size} users`);
      
      for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;
        
        // Get all messages by this user today with sentiment
        const messagesSnapshot = await admin.firestore()
          .collectionGroup('messages')
          .where('senderId', '==', userId)
          .where('type', '==', 'text')
          .where('createdAt', '>', oneDayAgo)
          .get();
        
        // Filter for messages with sentiment scores
        const messagesWithSentiment = messagesSnapshot.docs.filter(doc =>
          doc.data().sentimentScore !== undefined && doc.data().sentimentScore !== null
        );
        
        if (messagesWithSentiment.length === 0) {
          console.log(`⏭️ no sentiment data for user ${userId} today`);
          continue;
        }
        
        // Calculate average sentiment
        let totalSentiment = 0;
        const emotionCounts: { [emotion: string]: number } = {};
        
        for (const msgDoc of messagesWithSentiment) {
          const msg = msgDoc.data();
          totalSentiment += msg.sentimentScore;
          
          if (msg.sentimentAnalysis?.emotions) {
            for (const emotion of msg.sentimentAnalysis.emotions) {
              emotionCounts[emotion] = (emotionCounts[emotion] || 0) + 1;
            }
          }
        }
        
        const averageSentiment = totalSentiment / messagesWithSentiment.length;
        
        // Get yesterday's sentiment to determine trend
        const yesterdayStr = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().split('T')[0];
        const yesterdayDoc = await admin.firestore()
          .collection('sentimentTracking')
          .doc('userDaily')
          .collection('aggregates')
          .doc(`${yesterdayStr}_${userId}`)
          .get();
        
        let trend: 'improving' | 'stable' | 'declining' = 'stable';
        if (yesterdayDoc.exists) {
          const yesterdaySentiment = yesterdayDoc.data()?.averageSentiment || 0;
          const change = averageSentiment - yesterdaySentiment;
          if (change > 0.2) trend = 'improving';
          else if (change < -0.2) trend = 'declining';
        }
        
        // Save daily aggregate
        await admin.firestore()
          .collection('sentimentTracking')
          .doc('userDaily')
          .collection('aggregates')
          .doc(`${todayStr}_${userId}`)
          .set({
            userId: userId,
            date: todayStr,
            averageSentiment: averageSentiment,
            messageCount: messagesWithSentiment.length,
            emotionsDetected: emotionCounts,
            trend: trend,
            calculatedAt: admin.firestore.FieldValue.serverTimestamp()
          }, { merge: true });
        
        console.log(`✅ saved daily sentiment for user ${userId}: ${averageSentiment.toFixed(2)}`);
      }
      
      // ============================================
      // 2. CALCULATE TEAM DAILY AGGREGATES
      // ============================================
      console.log('📊 calculating team daily aggregates...');
      
      const conversationsSnapshot = await admin.firestore()
        .collection('conversations')
        .where('type', '==', 'group')
        .get();
      
      console.log(`💬 found ${conversationsSnapshot.size} group conversations`);
      
      for (const convoDoc of conversationsSnapshot.docs) {
        const conversationId = convoDoc.id;
        const conversation = convoDoc.data();
        const participantIds = conversation?.participantIds || [];
        
        // Get today's sentiment for each team member
        const memberSentiments: { [userId: string]: number } = {};
        let totalSentiment = 0;
        let memberCount = 0;
        
        for (const userId of participantIds) {
          const userDailyDoc = await admin.firestore()
            .collection('sentimentTracking')
            .doc('userDaily')
            .collection('aggregates')
            .doc(`${todayStr}_${userId}`)
            .get();
          
          if (userDailyDoc.exists) {
            const sentiment = userDailyDoc.data()?.averageSentiment || 0;
            memberSentiments[userId] = sentiment;
            totalSentiment += sentiment;
            memberCount++;
          }
        }
        
        if (memberCount === 0) {
          console.log(`⏭️ no sentiment data for team ${conversationId} today`);
          continue;
        }
        
        const teamAverageSentiment = totalSentiment / memberCount;
        
        // Determine trend
        const yesterdayStr = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().split('T')[0];
        const yesterdayTeamDoc = await admin.firestore()
          .collection('sentimentTracking')
          .doc('teamDaily')
          .collection('aggregates')
          .doc(`${yesterdayStr}_${conversationId}`)
          .get();
        
        let trend: 'improving' | 'stable' | 'declining' = 'stable';
        if (yesterdayTeamDoc.exists) {
          const yesterdayTeamSentiment = yesterdayTeamDoc.data()?.averageSentiment || 0;
          const change = teamAverageSentiment - yesterdayTeamSentiment;
          if (change > 0.15) trend = 'improving';
          else if (change < -0.15) trend = 'declining';
        }
        
        // Save team aggregate
        await admin.firestore()
          .collection('sentimentTracking')
          .doc('teamDaily')
          .collection('aggregates')
          .doc(`${todayStr}_${conversationId}`)
          .set({
            conversationId: conversationId,
            date: todayStr,
            averageSentiment: teamAverageSentiment,
            memberSentiments: memberSentiments,
            trend: trend,
            calculatedAt: admin.firestore.FieldValue.serverTimestamp()
          }, { merge: true });
        
        console.log(`✅ saved team sentiment for ${conversationId}: ${teamAverageSentiment.toFixed(2)}`);
        
        // ============================================
        // 3. CHECK FOR ALERTS
        // ============================================
        if (yesterdayTeamDoc.exists) {
          const yesterdayTeamSentiment = yesterdayTeamDoc.data()?.averageSentiment || 0;
          const drop = yesterdayTeamSentiment - teamAverageSentiment;
          
          // Alert if team sentiment dropped significantly
          if (drop > 0.3) {  // 15+ point drop on 0-100 scale
            console.log(`🚨 significant sentiment drop detected: ${drop.toFixed(2)}`);
            
            // Create alerts for participants
            for (const userId of participantIds) {
              const alertRef = admin.firestore()
                .collection('users').doc(userId)
                .collection('sentimentAlerts').doc();
              
              await alertRef.set({
                id: alertRef.id,
                conversationId: conversationId,
                type: 'team_drop',
                description: `team sentiment dropped ${Math.round(drop * 50)} points`,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                read: false
              });
            }
            
            console.log(`✅ sentiment drop alerts created`);
          }
        }
      }
      
      console.log('✅ sentiment aggregates calculation complete');
      
    } catch (error) {
      console.error('❌ error calculating sentiment aggregates:', error);
      // Don't throw - scheduled function shouldn't fail completely
    }
  });

