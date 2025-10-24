// Quick script to test AI features that ARE working

const admin = require('firebase-admin');
const serviceAccount = require('./path-to-service-account.json'); // You'll need to add this

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function testSentimentAnalysis() {
  console.log('🧪 Testing individual message sentiment...');
  
  // Query for recent messages with sentiment
  const messages = await db.collectionGroup('messages')
    .where('type', '==', 'text')
    .orderBy('createdAt', 'desc')
    .limit(10)
    .get();
  
  console.log(`\n📊 Found ${messages.size} recent messages:\n`);
  
  messages.forEach(doc => {
    const data = doc.data();
    if (data.sentimentScore !== undefined) {
      console.log(`✅ Message sentiment: ${data.sentimentScore}`);
      console.log(`   Text: "${data.text}"`);
      console.log(`   Emotions: ${data.sentimentAnalysis?.emotions?.join(', ')}`);
      console.log('');
    }
  });
}

testSentimentAnalysis().then(() => {
  console.log('✅ Test complete');
  process.exit(0);
}).catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
