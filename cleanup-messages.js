/**
 * cleanup-messages.js
 * Delete all messages from Firestore conversations
 * Run with: node cleanup-messages.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./functions/service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function deleteAllMessages() {
  console.log('🗑️  Starting message cleanup...');
  
  try {
    // Get all conversations
    const conversationsSnapshot = await db.collection('conversations').get();
    console.log(`📦 Found ${conversationsSnapshot.size} conversations`);
    
    let totalMessagesDeleted = 0;
    
    // For each conversation, delete all messages
    for (const conversationDoc of conversationsSnapshot.docs) {
      const conversationId = conversationDoc.id;
      console.log(`\n🔍 Processing conversation: ${conversationId}`);
      
      // Get all messages in this conversation
      const messagesSnapshot = await db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .get();
      
      console.log(`   Found ${messagesSnapshot.size} messages`);
      
      // Delete messages in batches of 500
      const batchSize = 500;
      const batches = [];
      let currentBatch = db.batch();
      let operationCount = 0;
      
      for (const messageDoc of messagesSnapshot.docs) {
        currentBatch.delete(messageDoc.ref);
        operationCount++;
        
        if (operationCount === batchSize) {
          batches.push(currentBatch.commit());
          currentBatch = db.batch();
          operationCount = 0;
        }
      }
      
      // Commit remaining operations
      if (operationCount > 0) {
        batches.push(currentBatch.commit());
      }
      
      // Wait for all batches to complete
      await Promise.all(batches);
      
      totalMessagesDeleted += messagesSnapshot.size;
      console.log(`   ✅ Deleted ${messagesSnapshot.size} messages from ${conversationId}`);
      
      // Update conversation to clear last message
      await conversationDoc.ref.update({
        lastMessage: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
    
    console.log(`\n✅ Cleanup complete!`);
    console.log(`📊 Total messages deleted: ${totalMessagesDeleted}`);
    console.log(`📊 Conversations processed: ${conversationsSnapshot.size}`);
    
  } catch (error) {
    console.error('❌ Error during cleanup:', error);
    throw error;
  } finally {
    await admin.app().delete();
    process.exit(0);
  }
}

// Run the cleanup
deleteAllMessages();

