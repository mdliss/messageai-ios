/**
 * Clear all messages from all conversations in Firestore
 * Run with: node clear-all-messages.js
 */

const admin = require('firebase-admin');

// Initialize without service account (will use default credentials)
admin.initializeApp({
  projectId: 'messageai-dc5fa'
});

const db = admin.firestore();

async function clearAllMessages() {
  console.log('🧹 Starting to clear all messages...');
  
  try {
    // Get all conversations
    const conversationsSnapshot = await db.collection('conversations').get();
    
    console.log(`📊 Found ${conversationsSnapshot.docs.length} conversations`);
    
    let totalMessagesDeleted = 0;
    
    for (const conversationDoc of conversationsSnapshot.docs) {
      const conversationId = conversationDoc.id;
      console.log(`\n🔍 Processing conversation: ${conversationId}`);
      
      // Get all messages in this conversation
      const messagesSnapshot = await db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .get();
      
      console.log(`   Found ${messagesSnapshot.docs.length} messages`);
      
      // Delete all messages in batches of 500
      const batch = db.batch();
      let batchCount = 0;
      
      for (const messageDoc of messagesSnapshot.docs) {
        batch.delete(messageDoc.ref);
        batchCount++;
        
        if (batchCount === 500) {
          await batch.commit();
          console.log(`   ✅ Deleted batch of ${batchCount} messages`);
          batchCount = 0;
        }
      }
      
      // Commit remaining messages
      if (batchCount > 0) {
        await batch.commit();
        console.log(`   ✅ Deleted final batch of ${batchCount} messages`);
      }
      
      totalMessagesDeleted += messagesSnapshot.docs.length;
      
      // Also clear insights
      const insightsSnapshot = await db
        .collection('conversations')
        .doc(conversationId)
        .collection('insights')
        .get();
      
      if (insightsSnapshot.docs.length > 0) {
        const insightsBatch = db.batch();
        insightsSnapshot.docs.forEach(doc => insightsBatch.delete(doc.ref));
        await insightsBatch.commit();
        console.log(`   ✅ Deleted ${insightsSnapshot.docs.length} insights`);
      }
    }
    
    console.log(`\n✅ COMPLETE: Deleted ${totalMessagesDeleted} total messages`);
    console.log('📝 You can now send fresh messages that will be properly indexed');
    
  } catch (error) {
    console.error('❌ Error clearing messages:', error);
  }
  
  process.exit(0);
}

clearAllMessages();

