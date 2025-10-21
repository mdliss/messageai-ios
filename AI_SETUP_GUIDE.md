# AI Features Setup Guide - OpenAI GPT Integration

## Quick Setup Steps

### 1. Install Firebase CLI (if not already installed)
```bash
npm install -g firebase-tools
```

### 2. Login to Firebase
```bash
firebase login
```

### 3. Install Function Dependencies
```bash
cd functions
npm install
```

### 4. Configure Your OpenAI API Key
```bash
firebase functions:config:set openai.key="YOUR_OPENAI_API_KEY_HERE"
```

Replace `YOUR_OPENAI_API_KEY_HERE` with your actual OpenAI API key.

### 5. Build the Functions
```bash
npm run build
```

### 6. Deploy to Firebase
```bash
cd ..
firebase deploy --only functions
```

This will deploy all 5 AI functions:
- `summarizeConversation` - Thread summarization
- `extractActionItems` - Action item extraction
- `detectPriority` - Priority message flagging
- `detectDecision` - Decision logging
- `detectProactiveSuggestions` - Scheduling assistance

---

## What Changed - Anthropic to OpenAI

### Updated Functions:
✅ `summarize.ts` - Now uses `gpt-4o` for summarization
✅ `actionItems.ts` - Now uses `gpt-4o` for action extraction  
✅ `priority.ts` - Now uses `gpt-4o-mini` for urgency rating
✅ `decisions.ts` - Now uses `gpt-4o-mini` for decision extraction
✅ `proactive.ts` - Now uses `gpt-4o-mini` for scheduling detection

### Model Selection:
- **gpt-4o**: Used for complex tasks (summarization, action items)
- **gpt-4o-mini**: Used for simple tasks (priority rating, decisions, proactive)

### Cost Optimization:
- Using gpt-4o-mini for simpler tasks saves ~80% on API costs
- Temperature set to 0.3-0.7 for consistent results
- Token limits optimized for each task type

---

## Verify Deployment

After deployment, check Firebase Console:
1. Go to Firebase Console → Functions
2. You should see 5 functions listed:
   - `summarizeConversation`
   - `extractActionItems`
   - `detectPriority`
   - `detectDecision`
   - `detectProactiveSuggestions`

3. Check function logs:
```bash
firebase functions:log
```

---

## Test AI Features in App

### 1. Thread Summarization
- Open any conversation
- Tap sparkles icon (top right)
- Tap "summarize"
- Wait 2-3 seconds
- AI insight card appears with 3 bullet points

### 2. Action Items
- Open conversation
- Tap sparkles icon
- Tap "action items"
- Wait 2-3 seconds
- AI card shows extracted action items

### 3. Priority Detection (Automatic)
- Send a message with: "URGENT: need this ASAP"
- Message automatically gets red border
- Works in real-time via Firestore trigger

### 4. Decision Tracking (Automatic)
- Send a message with: "decided to use React for frontend"
- Decision automatically logged
- View in "decisions" tab at bottom

### 5. Proactive Suggestions (Automatic)
- Send message with: "when can we schedule a meeting?"
- AI suggestion appears if confidence >80%
- Offers to help coordinate timing

---

## Troubleshooting

### Functions not deploying?
```bash
# Check if you're logged in
firebase login

# Check current project
firebase use

# Verify functions directory
cd functions && ls -la
```

### API key not working?
```bash
# View current config
firebase functions:config:get

# Should show:
# {
#   "openai": {
#     "key": "sk-..."
#   }
# }

# If missing, set it again:
firebase functions:config:set openai.key="sk-YOUR_KEY"
```

### Functions timing out?
- OpenAI GPT-4o should respond in 2-3 seconds
- If slower, check Firebase Functions logs
- May need to upgrade Firebase plan (Blaze) for external API calls

### Build errors?
```bash
cd functions
rm -rf node_modules package-lock.json
npm install
npm run build
```

---

## Firebase Console Setup Checklist

### ✅ Authentication
- Email/Password enabled
- Google Sign-In enabled (optional)

### ✅ Firestore Database
- Database created in production mode
- Security rules deployed (`firestore.rules`)
- Composite indexes deployed (`firestore.indexes.json`)

### ✅ Realtime Database
- Database created
- Security rules deployed (`database.rules.json`)

### ✅ Storage
- Storage bucket created
- Security rules deployed (`storage.rules`)

### ✅ Functions
- Upgraded to Blaze plan (required for external API calls)
- OpenAI API key configured
- All 5 functions deployed

---

## Expected Costs

### OpenAI API Costs (Approximate):
- **gpt-4o**: $2.50 per 1M input tokens, $10 per 1M output tokens
- **gpt-4o-mini**: $0.15 per 1M input tokens, $0.60 per 1M output tokens

### Per AI Feature Call:
- Summarization (100 messages): ~$0.02
- Action Items (100 messages): ~$0.02
- Priority Detection (1 message): ~$0.0001
- Decision Tracking (20 messages): ~$0.001
- Proactive Suggestions (20 messages): ~$0.001

**Total estimated cost for active usage: $1-5/month**

---

## Firebase Plan Requirements

**⚠️ IMPORTANT: You need the Blaze (Pay-as-you-go) plan**

Why? Firebase Functions can only make external API calls (like OpenAI) on the Blaze plan.

To upgrade:
1. Go to Firebase Console
2. Click "Upgrade" in bottom left
3. Select Blaze plan
4. Add billing information
5. Set budget alerts (recommended: $10/month)

Free tier includes:
- 2M function invocations/month
- 400K GB-seconds compute time
- Only pay for usage beyond free tier

---

## Quick Deploy Commands

```bash
# Full deployment (everything)
firebase deploy

# Functions only (faster)
firebase deploy --only functions

# Specific function
firebase deploy --only functions:summarizeConversation

# View logs in real-time
firebase functions:log --only summarizeConversation
```

---

## Next Steps

1. ✅ Run `cd functions && npm install` to install OpenAI SDK
2. ✅ Set OpenAI API key: `firebase functions:config:set openai.key="sk-..."`
3. ✅ Build functions: `npm run build`
4. ✅ Deploy: `firebase deploy --only functions`
5. ✅ Test in app by tapping summarize button
6. ✅ Check Firebase Console → Functions to see deployment status
7. ✅ Monitor logs: `firebase functions:log`

All AI features are ready to go once deployed! 🚀

