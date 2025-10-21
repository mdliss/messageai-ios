# Quick Start Guide - Getting Notifications Working

## Current Status
✅ App is running  
✅ Messages work in real-time  
✅ Notification permission granted  
⏳ Need to deploy Cloud Functions for notifications to actually send

---

## How Notifications Work

When User B sends a message to User A:
1. Message is saved to Firestore
2. **Cloud Function triggers** (sendMessageNotification)
3. Cloud Function gets User A's FCM token from Firestore
4. Cloud Function sends push notification via Firebase Cloud Messaging
5. User A's iPhone receives the notification

**Without Cloud Functions deployed, notifications won't send!**

---

## Deploy Cloud Functions (5 minutes)

### Step 1: Configure Anthropic API Key

You need an Anthropic API key for AI features. Get one at: https://console.anthropic.com

Then set it:
```bash
cd functions
firebase functions:config:set anthropic.key="YOUR_ANTHROPIC_API_KEY_HERE"
```

### Step 2: Login to Firebase

```bash
firebase login
```

### Step 3: Deploy Functions

```bash
firebase deploy --only functions
```

This will deploy:
- sendMessageNotification (for push notifications)
- summarizeConversation (AI summarization)
- extractActionItems (AI action items)
- detectPriority (urgent message detection)
- detectDecision (decision tracking)
- detectProactiveSuggestions (scheduling assistant)

### Step 4: Test Notifications

**Option A: Test on Physical Device (Recommended)**
1. Connect iPhone via USB
2. Select it in Xcode
3. Run the app
4. Send message from another device/simulator
5. You should get a notification!

**Option B: Test on Simulator (Limited)**
- Foreground notifications work
- Background notifications are unreliable
- Not recommended for final testing

---

## Check if FCM Token is Saved

Open Xcode console and look for:
```
🔔 Requesting notification permission...
✅ Notification permission GRANTED
🔑 Getting FCM token...
✅ FCM token retrieved: [long token]
📝 Saving FCM token to Firestore for user: [userId]
✅ FCM token saved to Firestore
```

If you see "⚠️ No user ID - cannot save FCM token", the token isn't being saved.

---

## Verify in Firebase Console

1. Go to Firebase Console
2. Firestore Database
3. Open `users` collection
4. Find your user document
5. Check if `fcmToken` field exists

---

## Message Alignment Explanation

The messages ARE correctly aligned:
- **Blue bubbles on RIGHT** = Your sent messages ✅
- **Grey bubbles on LEFT** = Received messages ✅

This is the standard chat UI (like iMessage, WhatsApp, etc.)

---

## Next Steps

1. Get Anthropic API key
2. Configure it: `firebase functions:config:set anthropic.key="..."`
3. Deploy: `firebase deploy --only functions`
4. Test notifications on physical device
5. Try AI features (summarize, action items)

---

## Troubleshooting

**If notifications still don't work after deploying:**
1. Check Cloud Functions logs: `firebase functions:log`
2. Verify FCM token in Firestore
3. Make sure APNs certificate is uploaded in Firebase Console
4. Test on physical device, not simulator

**If you see the crash about URL schemes:**
- This is a warning, not a crash
- Happens on first launch
- Doesn't affect functionality
- Will go away after Google Sign-In is properly configured

