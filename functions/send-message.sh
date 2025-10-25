#!/bin/bash

# Get the conversation ID
CONV_ID="65FE28AD-E4F7-48E8-B4B6-7074ED9EB7C4"

# Create message via curl to Firestore REST API
curl -X POST \
  "https://firestore.googleapis.com/v1/projects/messageai-dc5fa/databases/(default)/documents/conversations/${CONV_ID}/messages" \
  -H "Content-Type: application/json" \
  -d '{
    "fields": {
      "senderId": {"stringValue": "xQISSxzxCVTddxbB6cX9axK6kQo1"},
      "senderName": {"stringValue": "Test2"},
      "text": {"stringValue": "can you review this code before we deploy?"},
      "type": {"stringValue": "text"},
      "createdAt": {"timestampValue": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"},
      "readBy": {"mapValue": {}},
      "priority": {"stringValue": "normal"}
    }
  }'
