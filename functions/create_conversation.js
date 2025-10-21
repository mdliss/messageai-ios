const admin = require('firebase-admin');

const serviceAccount = {
  "type": "service_account",
  "project_id": "messageai-dc5fa"
};

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'messageai-dc5fa'
});

const db = admin.firestore();

async function createConversation() {
  const user1Id = 'el9lQBLhj4ZkvxbRV5ergFnFgeu2'; // Test3
  const user2Id = 'Hpw1fvzpl6Swe0LUc1dEiUbmB8i1'; // Test
  
  const conversationData = {
    id: `conv_${Date.now()}`,
    participantIds: [user1Id, user2Id],
    isGroup: false,
    createdAt: admin.firestore.Timestamp.now(),
    updatedAt: admin.firestore.Timestamp.now(),
    lastMessage: null,
    unreadCounts: {
      [user1Id]: 0,
      [user2Id]: 0
    }
  };
  
  const conversationRef = await db.collection('conversations').add(conversationData);
  console.log('✅ Conversation created:', conversationRef.id);
  console.log('Data:', conversationData);
  
  process.exit(0);
}

createConversation().catch(console.error);
