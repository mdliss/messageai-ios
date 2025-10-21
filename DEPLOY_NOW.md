# 🚀 Deploy AI Features - 3 Simple Commands

## What You Need
- ✅ OpenAI API key from https://platform.openai.com/api-keys
- ✅ Firebase project on Blaze plan (required for external API calls)

---

## Command 1: Set Your OpenAI API Key
```bash
firebase functions:config:set openai.key="sk-YOUR_OPENAI_API_KEY"
```

**Replace** `sk-YOUR_OPENAI_API_KEY` with your actual key.

Example:
```bash
firebase functions:config:set openai.key="sk-proj-abc123xyz789..."
```

---

## Command 2: Deploy Functions
```bash
firebase deploy --only functions
```

This deploys all 5 AI functions. Takes ~2-3 minutes.

---

## Command 3: Verify It Worked
```bash
firebase functions:list
```

You should see:
```
✔ summarizeConversation
✔ extractActionItems
✔ detectPriority
✔ detectDecision
✔ detectProactiveSuggestions
```

---

## ✅ That's It!

Now test in the app:
1. Open any conversation
2. Tap sparkles icon (top right)
3. Tap "summarize"
4. AI summary appears in 2-3 seconds

---

## 🐛 If Something Goes Wrong

### Check if key is set:
```bash
firebase functions:config:get
```

Should show:
```json
{
  "openai": {
    "key": "sk-..."
  }
}
```

### View function logs:
```bash
firebase functions:log
```

### Redeploy a specific function:
```bash
firebase deploy --only functions:summarizeConversation
```

---

## 💰 Expected Costs

**OpenAI API (with your usage):**
- Summarization: ~$0.02 per call
- Action Items: ~$0.02 per call
- Priority Detection: ~$0.0001 per message (automatic)
- Decisions: ~$0.001 per detection (automatic)
- Proactive: ~$0.001 per detection (automatic)

**Estimated monthly cost: $1-5** (very light usage)

**Firebase:**
- Functions: Free tier includes 2M invocations/month
- You'll likely stay within free tier

---

## 📱 What Firebase Console Should Show

After deployment, check Firebase Console (https://console.firebase.google.com):

**Functions Tab:**
- 5 functions listed
- All showing "Deployed" status
- Each has a green checkmark

**Firestore Tab:**
- Database created
- Collections: users, conversations
- Security rules deployed

**Authentication Tab:**
- Email/Password enabled
- Users can sign up/sign in

**Storage Tab:**
- Bucket created
- For message images
- Security rules deployed

**Realtime Database Tab:**
- Database created
- For typing indicators & presence
- Security rules deployed

---

## 🎯 Your Current Status

Based on your screenshot:
- ✅ Authentication - Enabled
- ✅ Firestore Database - Created
- ✅ Extensions - Optional
- ✅ Realtime Database - Created  
- ✅ Storage - Visible in sidebar

**What's Missing:**
- ⚠️ Need to deploy Functions (run the 2 commands above)
- ⚠️ Need to upgrade to Blaze plan (if not already)

---

## 🔥 Ready to Deploy!

**Everything is built and ready. Just run:**

```bash
# 1. Set key
firebase functions:config:set openai.key="YOUR_KEY"

# 2. Deploy
firebase deploy --only functions

# 3. Test in app
```

That's it! All AI features will be live! 🎉

