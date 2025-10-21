#!/usr/bin/env node
// add messages using firebase rest api

const https = require('https');

const PROJECT_ID = 'messageai-dc5fa';
const TEST_USER_ID = 'Hpw1fvzpl6Swe0LUc1dEiUbmB8i1'; // test@example.com
const TEST3_USER_ID = 'el9lQBLhj4ZkvxbRV5ergFnFgeu2'; // test3@example.com

// first, we need to find the conversation id
// let's query for conversations that include both users

async function findConversation() {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'firestore.googleapis.com',
      path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents:runQuery`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      }
    };

    const query = {
      structuredQuery: {
        from: [{collectionId: 'conversations'}],
        where: {
          fieldFilter: {
            field: {fieldPath: 'participantIds'},
            op: 'ARRAY_CONTAINS',
            value: {stringValue: TEST_USER_ID}
          }
        },
        orderBy: [{field: {fieldPath: 'createdAt'}, direction: 'DESCENDING'}]
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        if (res.statusCode === 200) {
          const result = JSON.parse(data);
          // filter to find conversation with both users
          for (const item of result) {
            if (item.document) {
              const doc = item.document;
              const participantIds = doc.fields.participantIds.arrayValue.values.map(v => v.stringValue);
              if (participantIds.includes(TEST_USER_ID) && participantIds.includes(TEST3_USER_ID)) {
                const conversationId = doc.name.split('/').pop();
                resolve(conversationId);
                return;
              }
            }
          }
          reject(new Error('no conversation found between test and test3'));
        } else {
          reject(new Error(`http ${res.statusCode}: ${data}`));
        }
      });
    });

    req.on('error', reject);
    req.write(JSON.stringify(query));
    req.end();
  });
}

async function addMessage(conversationId, senderId, senderName, text) {
  return new Promise((resolve, reject) => {
    const messageId = `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const now = new Date().toISOString();
    
    const options = {
      hostname: 'firestore.googleapis.com',
      path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents/messages/${messageId}`,
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
      }
    };

    const message = {
      fields: {
        id: {stringValue: messageId},
        conversationId: {stringValue: conversationId},
        senderId: {stringValue: senderId},
        senderName: {stringValue: senderName},
        type: {stringValue: 'text'},
        text: {stringValue: text},
        createdAt: {timestampValue: now},
        status: {stringValue: 'sent'},
        deliveredTo: {arrayValue: {values: [
          {stringValue: TEST_USER_ID},
          {stringValue: TEST3_USER_ID}
        ]}},
        readBy: {arrayValue: {values: []}},
        isSynced: {booleanValue: true}
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        if (res.statusCode === 200) {
          console.log(`✅ added message: "${text.substring(0, 40)}..."`);
          resolve();
        } else {
          reject(new Error(`http ${res.statusCode}: ${data}`));
        }
      });
    });

    req.on('error', reject);
    req.write(JSON.stringify(message));
    req.end();
  });
}

async function updateConversationLastMessage(conversationId, text, senderId) {
  return new Promise((resolve, reject) => {
    const now = new Date().toISOString();
    
    const options = {
      hostname: 'firestore.googleapis.com',
      path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents/conversations/${conversationId}?updateMask.fieldPaths=lastMessage&updateMask.fieldPaths=updatedAt`,
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
      }
    };

    const update = {
      fields: {
        lastMessage: {
          mapValue: {
            fields: {
              text: {stringValue: text},
              senderId: {stringValue: senderId},
              timestamp: {timestampValue: now}
            }
          }
        },
        updatedAt: {timestampValue: now}
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        if (res.statusCode === 200) {
          console.log(`✅ updated conversation last message`);
          resolve();
        } else {
          reject(new Error(`http ${res.statusCode}: ${data}`));
        }
      });
    });

    req.on('error', reject);
    req.write(JSON.stringify(update));
    req.end();
  });
}

async function main() {
  try {
    console.log('finding conversation between test and test3...');
    const conversationId = await findConversation();
    console.log(`found conversation: ${conversationId}`);
    
    // add test messages with realistic conversation
    const messages = [
      {sender: TEST3_USER_ID, name: 'Test3', text: 'hey can we meet tomorrow to discuss the project?'},
      {sender: TEST_USER_ID, name: 'Test', text: 'sure! what time works for you?'},
      {sender: TEST3_USER_ID, name: 'Test3', text: 'how about 2pm at the coffee shop on main street?'},
      {sender: TEST_USER_ID, name: 'Test', text: 'perfect! i will bring my laptop so we can review the designs'},
      {sender: TEST3_USER_ID, name: 'Test3', text: 'great idea. also dont forget to send me those files we talked about'},
      {sender: TEST_USER_ID, name: 'Test', text: 'will do! i will email them to you before lunch'},
      {sender: TEST3_USER_ID, name: 'Test3', text: 'thanks! looking forward to tomorrow'},
      {sender: TEST_USER_ID, name: 'Test', text: 'same here. see you then!'}
    ];
    
    console.log(`\nadding ${messages.length} messages to conversation...`);
    for (const msg of messages) {
      await addMessage(conversationId, msg.sender, msg.name, msg.text);
      await new Promise(resolve => setTimeout(resolve, 200)); // small delay between messages
    }
    
    // update conversation with last message
    const lastMsg = messages[messages.length - 1];
    await updateConversationLastMessage(conversationId, lastMsg.text, lastMsg.sender);
    
    console.log('\n✨ all done! conversation now has messages.');
    console.log('ai functions should start processing this conversation automatically.');
    console.log('check the ai insights in the app by long pressing the top right menu icon!');
    
  } catch (error) {
    console.error('error:', error.message);
    process.exit(1);
  }
}

main();

