const https = require('https');

const data = JSON.stringify({
  data: {
    conversationId: "test",
    messageId: "test",
    currentUserId: "test"
  }
});

const options = {
  hostname: 'us-central1-messageai-dc5fa.cloudfunctions.net',
  port: 443,
  path: '/generateResponseSuggestions',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length
  }
};

const req = https.request(options, (res) => {
  console.log(`Status Code: ${res.statusCode}`);
  console.log(`Headers: ${JSON.stringify(res.headers)}`);

  let responseData = '';
  res.on('data', (chunk) => {
    responseData += chunk;
  });

  res.on('end', () => {
    console.log('Response:', responseData);
  });
});

req.on('error', (error) => {
  console.error('Error:', error);
});

req.write(data);
req.end();
