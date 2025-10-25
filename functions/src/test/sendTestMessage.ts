/**
 * Test function to send a trigger message for response suggestions
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const sendTestTriggerMessage = functions
  .https.onCall(async (data, context) => {
    console.log('🧪 [TEST] Sending trigger message...');

    const conversationId = data.conversationId as string;

    if (!conversationId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'conversationId required'
      );
    }

    const messageData = {
      senderId: 'xQISSxzxCVTddxbB6cX9axK6kQo1', // Test2's ID
      senderName: 'Test2',
      text: 'can you review this code before we deploy?',
      type: 'text',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      readBy: {},
      priority: 'normal'
    };

    console.log('📨 [TEST] Creating message:', messageData.text);

    const messageRef = await admin.firestore()
      .collection('conversations')
      .doc(conversationId)
      .collection('messages')
      .add(messageData);

    console.log(`✅ [TEST] Message created: ${messageRef.id}`);
    console.log('🎯 [TEST] This message should trigger response suggestions!');

    return {
      success: true,
      messageId: messageRef.id,
      text: messageData.text
    };
  });
