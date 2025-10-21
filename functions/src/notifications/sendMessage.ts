/**
 * Send push notification when new message is created
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
  imageURL?: string;
  createdAt: admin.firestore.Timestamp;
  priority?: boolean;
}

interface User {
  id: string;
  fcmToken?: string;
  displayName: string;
}

/**
 * Send notification to all participants except sender
 */
export const sendMessageNotification = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data() as Message;
    const conversationId = context.params.conversationId;
    
    console.log(`📬 New message in conversation ${conversationId} from ${message.senderName}`);
    
    try {
      // Get conversation to find participants
      const conversationRef = admin.firestore()
        .collection('conversations')
        .doc(conversationId);
      
      const conversationDoc = await conversationRef.get();
      
      if (!conversationDoc.exists) {
        console.error('❌ Conversation not found');
        return;
      }
      
      const conversationData = conversationDoc.data();
      const participantIds = conversationData?.participantIds as string[] || [];
      
      // Get recipient IDs (exclude sender)
      const recipientIds = participantIds.filter(id => id !== message.senderId);
      
      if (recipientIds.length === 0) {
        console.log('ℹ️ No recipients to notify');
        return;
      }
      
      // Get FCM tokens for recipients
      const usersRef = admin.firestore().collection('users');
      const tokens: string[] = [];
      
      for (const recipientId of recipientIds) {
        const userDoc = await usersRef.doc(recipientId).get();
        const userData = userDoc.data() as User | undefined;
        
        if (userData?.fcmToken) {
          tokens.push(userData.fcmToken);
        }
      }
      
      if (tokens.length === 0) {
        console.log('ℹ️ No FCM tokens found for recipients');
        return;
      }
      
      // Prepare notification
      const notificationTitle = message.senderName;
      let notificationBody = '';
      
      if (message.type === 'text') {
        notificationBody = message.text;
      } else if (message.type === 'image') {
        notificationBody = '📷 Photo';
      }
      
      // Truncate long messages
      if (notificationBody.length > 100) {
        notificationBody = notificationBody.substring(0, 97) + '...';
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
          type: 'new_message',
        },
        apns: {
          payload: {
            aps: {
              sound: message.priority ? 'default' : 'default',
              badge: 1,
            },
          },
        },
      };
      
      // Send notification
      const response = await admin.messaging().sendEachForMulticast(notificationPayload);
      
      console.log(`✅ Notifications sent: ${response.successCount} succeeded, ${response.failureCount} failed`);
      
      // Log failures
      if (response.failureCount > 0) {
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.error(`❌ Failed to send to token ${tokens[idx]}: ${resp.error}`);
          }
        });
      }
      
    } catch (error) {
      console.error('❌ Error sending notification:', error);
    }
  });

