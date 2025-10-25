/**
 * Send push notification when user is mentioned in a message
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

interface Message {
  id: string;
  conversationId: string;
  senderId: string;
  senderName: string;
  type: 'text' | 'image';
  text: string;
  mentionedUserIds?: string[];
  createdAt: admin.firestore.Timestamp;
}

interface User {
  id: string;
  fcmToken?: string;
  displayName: string;
}

/**
 * Send notification to mentioned users
 */
export const sendMentionNotification = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data() as Message;
    const conversationId = context.params.conversationId;

    // Only proceed if message has mentions
    if (!message.mentionedUserIds || message.mentionedUserIds.length === 0) {
      return;
    }

    console.log(`💬 Message with mentions in conversation ${conversationId} from ${message.senderName}`);
    console.log(`   Mentioned users: ${message.mentionedUserIds.join(', ')}`);

    try {
      // Get conversation details
      const conversationRef = admin.firestore()
        .collection('conversations')
        .doc(conversationId);

      const conversationDoc = await conversationRef.get();

      if (!conversationDoc.exists) {
        console.error('❌ Conversation not found');
        return;
      }

      // Get FCM tokens for mentioned users
      const usersRef = admin.firestore().collection('users');
      const tokens: string[] = [];

      for (const mentionedUserId of message.mentionedUserIds) {
        // Don't notify the sender
        if (mentionedUserId === message.senderId) {
          continue;
        }

        const userDoc = await usersRef.doc(mentionedUserId).get();
        const userData = userDoc.data() as User | undefined;

        if (userData?.fcmToken) {
          tokens.push(userData.fcmToken);
        }
      }

      if (tokens.length === 0) {
        console.log('ℹ️ No FCM tokens found for mentioned users');
        return;
      }

      // Prepare notification
      const notificationTitle = `${message.senderName} mentioned you`;
      let notificationBody = '';

      if (message.type === 'text') {
        // Truncate long messages
        notificationBody = message.text.length > 100
          ? message.text.substring(0, 97) + '...'
          : message.text;
      } else if (message.type === 'image') {
        notificationBody = '📷 Photo';
      }

      const notificationPayload: admin.messaging.MulticastMessage = {
        tokens: tokens,
        notification: {
          title: notificationTitle,
          body: notificationBody,
        },
        data: {
          conversationId: conversationId,
          messageId: message.id,
          senderId: message.senderId,
          type: 'mention',
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      // Send notification
      const response = await admin.messaging().sendEachForMulticast(notificationPayload);

      console.log(`✅ Mention notifications sent: ${response.successCount} succeeded, ${response.failureCount} failed`);

      // Log failures
      if (response.failureCount > 0) {
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.error(`❌ Failed to send to token ${tokens[idx]}: ${resp.error}`);
          }
        });
      }

    } catch (error) {
      console.error('❌ Error sending mention notification:', error);
    }
  });
