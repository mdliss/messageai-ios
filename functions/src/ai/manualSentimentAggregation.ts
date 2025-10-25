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
    console.log('📊 [MANUAL_AGG] manual sentiment aggregation started...');
    console.log('📊 [MANUAL_AGG] request data:', JSON.stringify(data));

    const conversationId = data.conversationId as string;

    if (!conversationId) {
      console.error('❌ [MANUAL_AGG] missing conversationId parameter');
      throw new functions.https.HttpsError(
        'invalid-argument',
        'conversationId required'
      );
    }

    const now = new Date();
    const todayStr = now.toISOString().split('T')[0]; // yyyy-mm-dd
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

    console.log('📅 [MANUAL_AGG] today:', todayStr);
    console.log('📅 [MANUAL_AGG] querying messages since:', oneDayAgo.toISOString());
    
    try {
      // ============================================
      // 1. GET CONVERSATION INFO
      // ============================================
      const convoDoc = await admin.firestore()
        .collection('conversations').doc(conversationId)
        .get();

      console.log(`🔍 [MANUAL_AGG] conversation document exists: ${convoDoc.exists}`);

      if (!convoDoc.exists) {
        console.error(`❌ [MANUAL_AGG] conversation ${conversationId} not found`);
        throw new functions.https.HttpsError('not-found', 'conversation not found');
      }

      const conversation = convoDoc.data();
      const participantIds = conversation?.participantIds || [];

      console.log(`👥 [MANUAL_AGG] found ${participantIds.length} participants:`, participantIds);
      
      // ============================================
      // 2. CALCULATE USER DAILY AGGREGATES
      // ============================================
      const memberSentiments: { [userId: string]: number } = {};
      
      for (const userId of participantIds) {
        console.log(`👤 [MANUAL_AGG] processing user: ${userId}`);

        // Query THIS conversation's messages only (no index needed)
        const messagesSnapshot = await admin.firestore()
          .collection('conversations').doc(conversationId)
          .collection('messages')
          .where('senderId', '==', userId)
          .where('type', '==', 'text')
          .where('createdAt', '>', oneDayAgo)
          .get();

        console.log(`📨 [MANUAL_AGG] found ${messagesSnapshot.docs.length} messages for user ${userId}`);

        // Filter for messages with sentiment scores
        const messagesWithSentiment = messagesSnapshot.docs.filter(doc =>
          doc.data().sentimentScore !== undefined && doc.data().sentimentScore !== null
        );

        console.log(`📊 [MANUAL_AGG] ${messagesWithSentiment.length} messages have sentiment scores`);

        if (messagesWithSentiment.length === 0) {
          console.log(`⏭️ [MANUAL_AGG] no sentiment data for user ${userId}`);
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

        console.log(`✅ [MANUAL_AGG] user ${userId}: ${averageSentiment.toFixed(2)} (${messagesWithSentiment.length} messages)`);
        console.log(`😊 [MANUAL_AGG] emotions for ${userId}:`, emotionCounts);
        
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
      console.log(`📊 [MANUAL_AGG] calculating team aggregate from ${Object.keys(memberSentiments).length} members...`);

      if (Object.keys(memberSentiments).length === 0) {
        console.log('⏭️ [MANUAL_AGG] no sentiment data for team today');
        return {
          success: true,
          message: 'no sentiment data available'
        };
      }

      const totalSentiment = Object.values(memberSentiments).reduce((a, b) => a + b, 0);
      const teamAverageSentiment = totalSentiment / Object.keys(memberSentiments).length;

      console.log(`📊 [MANUAL_AGG] team average sentiment: ${teamAverageSentiment.toFixed(2)}`);
      console.log(`📊 [MANUAL_AGG] member sentiments breakdown:`, memberSentiments);
      
      // Save team aggregate
      const aggregateDocPath = `${todayStr}_${conversationId}`;
      console.log(`💾 [MANUAL_AGG] saving team aggregate to: sentimentTracking/teamDaily/aggregates/${aggregateDocPath}`);

      const aggregateData = {
        conversationId: conversationId,
        date: todayStr,
        averageSentiment: teamAverageSentiment,
        memberSentiments: memberSentiments,
        trend: 'stable',  // Can calculate this later
        calculatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      console.log(`📊 [MANUAL_AGG] aggregate data to save:`, aggregateData);

      await admin.firestore()
        .collection('sentimentTracking')
        .doc('teamDaily')
        .collection('aggregates')
        .doc(aggregateDocPath)
        .set(aggregateData, { merge: true });

      console.log('✅ [MANUAL_AGG] manual aggregation complete - team aggregate saved');

      return {
        success: true,
        teamSentiment: teamAverageSentiment,
        memberCount: Object.keys(memberSentiments).length,
        memberSentiments: memberSentiments,
        documentPath: `sentimentTracking/teamDaily/aggregates/${aggregateDocPath}`
      };

    } catch (error: any) {
      console.error('❌ [MANUAL_AGG] manual aggregation error:', error);
      console.error('❌ [MANUAL_AGG] error stack:', error.stack);
      throw new functions.https.HttpsError(
        'internal',
        'failed to aggregate sentiment',
        error.message
      );
    }
  });

