/**
 * Test script to send a message from Test2 that will trigger response suggestions
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin with project ID
admin.initializeApp({
  projectId: 'messageai-dc5fa'
});

async function sendTriggerMessage() {
  console.log('🧪 Sending trigger message from Test2...');

  const db = admin.firestore();

  // Find the conversation (Test Group)
  console.log('🔍 Finding group conversation...');
  const conversationsSnapshot = await db.collection('conversations')
    .where('type', '==', 'group')
    .limit(1)
    .get();

  if (conversationsSnapshot.empty) {
    console.error('❌ No group conversation found');
    process.exit(1);
  }

  const conversationId = conversationsSnapshot.docs[0].id;
  console.log(`✅ Found conversation: ${conversationId}`);

  // Test2's user ID (from the messages we saw)
  const test2UserId = 'xQISSxzxCVTddxbB6cX9axK6kQo1';

  // Create the trigger message
  const messageData = {
    senderId: test2UserId,
    senderName: 'Test2',
    text: 'can you review this code before we deploy?',
    type: 'text',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    readBy: {},
    priority: 'normal'
  };

  console.log('📨 Creating message:', messageData.text);

  const messageRef = await db.collection('conversations')
    .doc(conversationId)
    .collection('messages')
    .add(messageData);

  console.log(`✅ Message created with ID: ${messageRef.id}`);
  console.log('');
  console.log('🎯 This message should trigger response suggestions because:');
  console.log('   1. It ends with "?"');
  console.log('   2. It contains "can you" (request keyword)');
  console.log('   3. It\'s from Test2, not the current user (Test)');
  console.log('');
  console.log('💡 Watch for suggestions to appear in the ChatView!');

  process.exit(0);
}

sendTriggerMessage().catch(error => {
  console.error('❌ Error:', error);
  process.exit(1);
});
