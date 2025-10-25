/**
 * Emoji Reaction → Sentiment Tracking
 *
 * Processes emoji reactions on messages and updates sentiment:
 * - Positive reactions (👍❤️🎉) → +1.0 sentiment
 * - Neutral reactions (😮🤔) → 0.0 sentiment
 * - Negative reactions (😤😡😢) → -1.0 sentiment
 *
 * Updates message-level sentiment and re-aggregates team sentiment
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Map emoji to sentiment score
 * @param emoji - Emoji string
 * @returns Sentiment score (-1.0 to 1.0)
 */
function emojiToSentiment(emoji: string): number {
  const sentimentMapping: { [key: string]: number } = {
    // Positive reactions
    '👍': 1.0,
    '❤️': 1.0,
    '🎉': 1.0,
    '😂': 0.8,
    '😊': 0.8,
    '👏': 1.0,
    '🙌': 1.0,
    '✅': 0.6,

    // Neutral reactions
    '😮': 0.0,
    '🤔': 0.0,
    '👀': 0.0,

    // Negative reactions
    '😢': -0.8,
    '😤': -1.0,
    '😡': -1.0,
    '👎': -1.0,
    '😞': -0.8,
    '😰': -0.6,
  };

  return sentimentMapping[emoji] ?? 0.0;
}

/**
 * Calculate average sentiment from reactions
 * @param reactions - Reactions map {userId: emoji}
 * @returns Average sentiment score
 */
function calculateReactionSentiment(reactions: { [userId: string]: string }): number {
  const emojis = Object.values(reactions);
  if (emojis.length === 0) return 0.0;

  const scores = emojis.map(emojiToSentiment);
  const sum = scores.reduce((a, b) => a + b, 0);
  return sum / scores.length;
}

/**
 * Cloud Function: Process emoji reaction and update sentiment
 * Triggered when a reaction is added/updated on a message
 */
export const processReactionSentiment = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onUpdate(async (change, context) => {
    const { conversationId, messageId } = context.params;
    const before = change.before.data();
    const after = change.after.data();

    // Check if reactions changed
    const reactionsBefore = before.reactions || {};
    const reactionsAfter = after.reactions || {};

    if (JSON.stringify(reactionsBefore) === JSON.stringify(reactionsAfter)) {
      console.log('No reaction changes, skipping sentiment update');
      return null;
    }

    console.log('📝 Processing reaction sentiment update:', {
      conversationId,
      messageId,
      reactionsBefore,
      reactionsAfter,
    });

    try {
      // Calculate reaction sentiment
      const reactionSentiment = calculateReactionSentiment(reactionsAfter);

      console.log(`✅ Calculated reaction sentiment: ${reactionSentiment}`);

      // Update message with reaction sentiment
      const db = admin.firestore();
      await db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
          reactionSentiment,
          reactionCount: Object.keys(reactionsAfter).length,
        });

      console.log(`✅ Updated message with reaction sentiment: ${reactionSentiment}`);

      // Trigger team sentiment re-aggregation (if in group chat)
      const conversationDoc = await db
        .collection('conversations')
        .doc(conversationId)
        .get();

      const conversationType = conversationDoc.data()?.type;

      if (conversationType === 'group') {
        console.log('📊 Re-aggregating team sentiment for group conversation...');
        await aggregateTeamSentiment(conversationId);
      }

      return null;
    } catch (error) {
      console.error('❌ Error processing reaction sentiment:', error);
      throw error;
    }
  });

/**
 * Re-aggregate team sentiment for a conversation
 * Called after reaction changes in group chats
 * @param conversationId - Conversation ID
 */
async function aggregateTeamSentiment(conversationId: string): Promise<void> {
  try {
    const db = admin.firestore();
    const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD

    // Get all messages from today with sentiment or reactions
    const messagesSnapshot = await db
      .collection('conversations')
      .doc(conversationId)
      .collection('messages')
      .where('createdAt', '>=', new Date(today))
      .get();

    if (messagesSnapshot.empty) {
      console.log('No messages found for today, skipping aggregation');
      return;
    }

    const sentimentScores: number[] = [];

    // Collect all sentiment scores (both AI sentiment and reaction sentiment)
    messagesSnapshot.forEach((doc: admin.firestore.QueryDocumentSnapshot) => {
      const data = doc.data();

      // AI-generated sentiment (if available)
      if (data.sentimentScore !== undefined && data.sentimentScore !== null) {
        sentimentScores.push(data.sentimentScore);
      }

      // Reaction sentiment (if available)
      if (data.reactionSentiment !== undefined && data.reactionSentiment !== null) {
        sentimentScores.push(data.reactionSentiment);
      }
    });

    if (sentimentScores.length === 0) {
      console.log('No sentiment scores found, skipping aggregation');
      return;
    }

    // Calculate average sentiment
    const averageSentiment = sentimentScores.reduce((a, b) => a + b, 0) / sentimentScores.length;

    console.log(`📊 Aggregated sentiment: ${averageSentiment} (from ${sentimentScores.length} scores)`);

    // Store in daily aggregate
    await db
      .collection('sentimentTracking')
      .doc('teamDaily')
      .collection('aggregates')
      .doc(`${today}_${conversationId}`)
      .set({
        conversationId,
        date: today,
        averageSentiment,
        messageCount: messagesSnapshot.size,
        sentimentScoreCount: sentimentScores.length,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

    console.log(`✅ Team sentiment aggregated for ${conversationId} on ${today}`);
  } catch (error) {
    console.error('❌ Error aggregating team sentiment:', error);
    throw error;
  }
}
