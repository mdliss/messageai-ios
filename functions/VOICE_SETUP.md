# Voice Memo Transcription Setup

## Security: Environment Variables

The OpenAI API key is stored securely in Firebase Cloud Functions environment variables.
**NEVER** put API keys in code or config files that get deployed with the iOS app.

## Setup Instructions

### 1. Set OpenAI API Key in Firebase Functions

```bash
# Navigate to functions directory
cd functions

# Set the environment variable (replace with your actual key)
firebase functions:config:set openai.api_key="sk-..."

# Verify it's set
firebase functions:config:get
```

### 2. Deploy Functions

```bash
# Deploy only voice functions
firebase deploy --only functions:transcribeVoiceMemo,functions:retranscribeVoiceMemo

# Or deploy all functions
firebase deploy --only functions
```

### 3. Verify Deployment

Check Firebase Console > Functions to see:
- `transcribeVoiceMemo` - Auto-triggers on new voice messages
- `retranscribeVoiceMemo` - Manual retry endpoint

## How It Works

1. **iOS app** records audio and uploads to Firebase Storage
2. **iOS app** creates message document with `type: "voice"` and `voiceURL`
3. **Cloud Function** (`transcribeVoiceMemo`) automatically triggers
4. **Cloud Function** downloads audio, calls OpenAI Whisper API (using secure env var)
5. **Cloud Function** updates message with transcription
6. **iOS app** displays transcription (via real-time listener)

## Cost Estimation

OpenAI Whisper API pricing (as of 2024):
- $0.006 per minute of audio
- 1 minute voice memo = ~$0.006
- 100 voice memos/day = ~$0.60/day = ~$18/month

## Testing

```bash
# View function logs
firebase functions:log --only transcribeVoiceMemo

# Test manual retry
firebase functions:call retranscribeVoiceMemo --data '{"messageId":"xxx","conversationId":"yyy"}'
```

## Security Checklist

✅ API key stored in Cloud Functions environment
✅ iOS app never sees API key
✅ All API calls go through Cloud Functions
✅ User authentication required for manual retry
✅ Firebase Storage security rules prevent unauthorized access
