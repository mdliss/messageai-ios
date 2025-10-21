# Firebase Commands Quick Reference

## 🚀 Deploy AI Features (What You Need To Do)

### Step 1: Set OpenAI API Key
```bash
firebase functions:config:set openai.key="sk-YOUR_OPENAI_API_KEY_HERE"
```
**Replace** `sk-YOUR_OPENAI_API_KEY_HERE` with your actual OpenAI API key from https://platform.openai.com/api-keys

### Step 2: Deploy Functions
```bash
firebase deploy --only functions
```

Wait 2-3 minutes for deployment to complete.

### Step 3: Verify Deployment
```bash
firebase functions:list
```

Should show:
- summarizeConversation
- extractActionItems
- detectPriority
- detectDecision
- detectProactiveSuggestions

---

## 📋 Other Useful Commands

### View Current Configuration
```bash
firebase functions:config:get
```

### View Function Logs
```bash
firebase functions:log
```

### View Real-Time Logs
```bash
firebase functions:log --only summarizeConversation
```

### Deploy Everything
```bash
firebase deploy
```

### Deploy Only Firestore Rules
```bash
firebase deploy --only firestore:rules
```

### Deploy Only Indexes
```bash
firebase deploy --only firestore:indexes
```

### Test Functions Locally (Optional)
```bash
cd functions
npm run serve
```

---

## ⚡ Quick Testing

### Test Summarization:
1. Open app → go to any conversation
2. Tap sparkles icon (top right)
3. Tap "summarize"
4. Wait 2-3 seconds → AI card appears

### Test Action Items:
1. Same as above
2. Tap "action items"
3. AI extracts tasks with owners

### Test Priority Detection:
1. Send message: "URGENT: need this ASAP"
2. Message gets red border automatically

---

## ⚠️ Important Notes

### Firebase Blaze Plan Required
- Free tier **cannot** make external API calls
- Upgrade at: Firebase Console → Upgrade → Blaze Plan
- Set budget alert to $10/month to avoid surprises

### OpenAI API Key
- Get from: https://platform.openai.com/api-keys
- Add billing at: https://platform.openai.com/account/billing
- Recommended: Set usage limit to $10/month

### Firestore Indexes
- Already configured in `firestore.indexes.json`
- Deploy with: `firebase deploy --only firestore:indexes`
- Required for complex queries

---

## 🐛 Troubleshooting

### "OpenAI API key not configured" error:
```bash
# Check current config
firebase functions:config:get

# If empty or missing openai.key, set it:
firebase functions:config:set openai.key="sk-YOUR_KEY"

# After setting, redeploy:
firebase deploy --only functions
```

### Functions not appearing in Firebase Console:
```bash
# Make sure you're on the right project
firebase use

# Redeploy
firebase deploy --only functions
```

### Build errors:
```bash
cd functions
npm install
npm run build
```

### "Insufficient permissions" error:
- Check Firebase Console → Authentication
- Make sure Email/Password is enabled
- User must be signed in to call functions

---

## 📊 Monitor AI Feature Usage

### View Logs
```bash
firebase functions:log --limit 50
```

### Check Specific Function
```bash
firebase functions:log --only summarizeConversation --limit 10
```

### Monitor in Real-Time
```bash
firebase functions:log --follow
```

Then use the app and watch logs appear live!

---

## ✅ Deployment Checklist

Before deploying, make sure:
- ✅ OpenAI API key obtained from OpenAI platform
- ✅ Firebase upgraded to Blaze plan
- ✅ `npm install` completed in functions/
- ✅ `npm run build` successful (no errors)
- ✅ API key set via `firebase functions:config:set`
- ✅ Ready to run `firebase deploy --only functions`

After deploying:
- ✅ Check Firebase Console → Functions (should see 5 functions)
- ✅ Test summarize button in app
- ✅ Check logs: `firebase functions:log`
- ✅ Send urgent message to test priority detection
- ✅ View decisions tab to see logged decisions

---

**Everything is ready! Just set your OpenAI API key and deploy! 🚀**

