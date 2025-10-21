#!/usr/bin/env node
// script to create test conversation and messages for testing ai features

const admin = require('firebase-admin');

// initialize firebase admin with application default credentials
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'messageai-dc5fa'
});

const db = admin.firestore();

async function createTestConversation() {
  console.log('creating test conversation between test@example.com and test3@example.com...');
  
  // use known user ids from existing script
  const testUserId = 'Hpw1fvzpl6Swe0LUc1dEiUbmB8i1'; // test@example.com
  const test3UserId = 'el9lQBLhj4ZkvxbRV5ergFnFgeu2'; // test3@example.com
  
  console.log('test user id:', testUserId);
  console.log('test3 user id:', test3UserId);
  
  // create conversation
  const conversationId = `conv_${Date.now()}`;
  const now = admin.firestore.Timestamp.now();
  
  const conversation = {
    id: conversationId,
    type: 'direct',
    participantIds: [testUserId, test3UserId],
    participantDetails: {
      [testUserId]: {
        displayName: 'Test',
        photoURL: null
      },
      [test3UserId]: {
        displayName: 'Test3',
        photoURL: null
      }
    },
    unreadCount: {
      [testUserId]: 0,
      [test3UserId]: 0
    },
    createdAt: now,
    updatedAt: now
  };
  
  await db.collection('conversations').doc(conversationId).set(conversation);
  console.log('created conversation:', conversationId);
  
  // create test messages
  const messages = [
    {
      senderId: testUserId,
      senderName: 'Test',
      text: 'hey, can we meet tomorrow to discuss the project?'
    },
    {
      senderId: test3UserId,
      senderName: 'Test3',
      text: 'sure! what time works for you?'
    },
    {
      senderId: testUserId,
      senderName: 'Test',
      text: 'how about 2pm at the coffee shop on main street?'
    },
    {
      senderId: test3UserId,
      senderName: 'Test3',
      text: 'perfect! i\'ll bring my laptop so we can review the designs'
    },
    {
      senderId: testUserId,
      senderName: 'Test',
      text: 'great. also, don\'t forget to send me those files we talked about'
    },
    {
      senderId: test3UserId,
      senderName: 'Test3',
      text: 'will do! i\'ll email them to you before lunch'
    },
    {
      senderId: testUserId,
      senderName: 'Test',
      text: 'thanks! see you tomorrow'
    }
  ];
  
  // add messages with delays to simulate real conversation
  for (let i = 0; i < messages.length; i++) {
    const msg = messages[i];
    const messageId = `msg_${Date.now()}_${i}`;
    const timestamp = admin.firestore.Timestamp.fromMillis(now.toMillis() + (i * 60000)); // 1 minute apart
    
    const message = {
      id: messageId,
      conversationId: conversationId,
      senderId: msg.senderId,
      senderName: msg.senderName,
      senderPhotoURL: null,
      type: 'text',
      text: msg.text,
      createdAt: timestamp,
      status: 'sent',
      deliveredTo: [testUserId, test3UserId],
      readBy: [],
      isSynced: true
    };
    
    await db.collection('messages').doc(messageId).set(message);
    console.log(`created message ${i + 1}/${messages.length}: "${msg.text.substring(0, 30)}..."`);
  }
  
  // update conversation with last message
  const lastMessage = messages[messages.length - 1];
  const lastTimestamp = admin.firestore.Timestamp.fromMillis(now.toMillis() + ((messages.length - 1) * 60000));
  
  await db.collection('conversations').doc(conversationId).update({
    lastMessage: {
      text: lastMessage.text,
      senderId: lastMessage.senderId,
      timestamp: lastTimestamp
    },
    updatedAt: lastTimestamp
  });
  
  console.log('conversation created successfully!');
  console.log('conversation id:', conversationId);
  console.log('total messages:', messages.length);
  console.log('ai features should start processing this conversation now...');
}

createTestConversation()
  .then(() => {
    console.log('done!');
    process.exit(0);
  })
  .catch(error => {
    console.error('error:', error);
    process.exit(1);
  });

