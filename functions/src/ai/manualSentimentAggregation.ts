/**
 * Manual Sentiment Aggregation (No Index Required)
 * 
 * Workaround for when the composite index is still building.
 * This queries conversations individually instead of using collectionGroup.
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Manual aggregation that works without composite index
 * Call this directly to aggregate sentiment for a specific conversation
 */
export const manualAggregateSentiment = functions
  .https.onCall(async (data, context) => {
    console.log('📊 manual sentiment aggregation started...');
    
    const conversationId = data.conversationId as string;
    
    if (!conversationId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'conversationId required'
      );
    }
    
    const now = new Date();
    const todayStr = now.toISOString().split('T')[0]; // yyyy-mm-dd
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    
    try {
      // ============================================
      // 1. GET CONVERSATION INFO
      // ============================================
      const convoDoc = await admin.firestore()
        .collection('conversations').doc(conversationId)
        .get();
      
      if (!convoDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'conversation not found');
      }
      
      const conversation = convoDoc.data();
      const participantIds = conversation?.participantIds || [];
      
      console.log(`👥 found ${participantIds.length} participants`);
      
      // ============================================
      // 2. CALCULATE USER DAILY AGGREGATES
      // ============================================
      const memberSentiments: { [userId: string]: number } = {};
      
      for (const userId of participantIds) {
        // Query THIS conversation's messages only (no index needed)
        const messagesSnapshot = await admin.firestore()
          .collection('conversations').doc(conversationId)
          .collection('messages')
          .where('senderId', '==', userId)
          .where('type', '==', 'text')
          .where('createdAt', '>', oneDayAgo)
          .get();
        
        // Filter for messages with sentiment scores
        const messagesWithSentiment = messagesSnapshot.docs.filter(doc =>
          doc.data().sentimentScore !== undefined && doc.data().sentimentScore !== null
        );
        
        if (messagesWithSentiment.length === 0) {
          console.log(`⏭️ no sentiment data for user ${userId}`);
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
        memberSentiments[userId] = averageSentiment;
        
        console.log(`✅ user ${userId}: ${averageSentiment.toFixed(2)} (${messagesWithSentiment.length} messages)`);
        
        // Save user daily aggregate
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
            trend: 'stable',  // Can calculate this later
            calculatedAt: admin.firestore.FieldValue.serverTimestamp()
          }, { merge: true });
      }
      
      // ============================================
      // 3. CALCULATE TEAM AGGREGATE
      // ============================================
      if (Object.keys(memberSentiments).length === 0) {
        console.log('⏭️ no sentiment data for team today');
        return {
          success: true,
          message: 'no sentiment data available'
        };
      }
      
      const totalSentiment = Object.values(memberSentiments).reduce((a, b) => a + b, 0);
      const teamAverageSentiment = totalSentiment / Object.keys(memberSentiments).length;
      
      console.log(`📊 team average sentiment: ${teamAverageSentiment.toFixed(2)}`);
      
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
          trend: 'stable',  // Can calculate this later
          calculatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
      
      console.log('✅ manual aggregation complete');
      
      return {
        success: true,
        teamSentiment: teamAverageSentiment,
        memberCount: Object.keys(memberSentiments).length,
        memberSentiments: memberSentiments
      };
      
    } catch (error: any) {
      console.error('❌ manual aggregation error:', error);
      throw new functions.https.HttpsError(
        'internal',
        'failed to aggregate sentiment',
        error.message
      );
    }
  });

