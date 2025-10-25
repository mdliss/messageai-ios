const { initializeApp } = require('firebase/app');
const { getFirestore, collection, addDoc, serverTimestamp, query, where, limit, getDocs } = require('firebase/firestore');

const firebaseConfig = {
  projectId: 'messageai-dc5fa',
  apiKey: 'AIzaSyDummyKey' // Not needed for Firestore operations
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function addTriggerMessage() {
  console.log('🧪 Adding trigger message from Test2...');
  
  // Find group conversation
  const conversationsRef = collection(db, 'conversations');
  const q = query(conversationsRef, where('type', '==', 'group'), limit(1));
  const snapshot = await getDocs(q);
  
  if (snapshot.empty) {
    console.error('❌ No group conversation found');
    return;
  }
  
  const conversationId = snapshot.docs[0].id;
  console.log(`✅ Found conversation: ${conversationId}`);
  
  const messagesRef = collection(db, 'conversations', conversationId, 'messages');
  
  const messageData = {
    senderId: 'xQISSxzxCVTddxbB6cX9axK6kQo1',
    senderName: 'Test2',
    text: 'can you review this code before we deploy?',
    type: 'text',
    createdAt: serverTimestamp(),
    readBy: {},
    priority: 'normal'
  };
  
  console.log('📨 Creating message:', messageData.text);
  const docRef = await addDoc(messagesRef, messageData);
  console.log(`✅ Message created with ID: ${docRef.id}`);
  console.log('🎯 Message should trigger suggestions!');
}

addTriggerMessage().catch(console.error);
