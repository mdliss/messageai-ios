# Testing Presence System

## Step 1: Rebuild and Run

1. **Clean Build** (Shift+Cmd+K)
2. **Run** (Cmd+R)

## Step 2: Watch Xcode Console

When you launch the app, you should see:

```
✅ Firebase initialized successfully
📱 Project ID: messageai-dc5fa
🔥 Realtime DB URL: https://messageai-dc5fa-default-rtdb.firebaseio.com/
```

Then when you sign in:

```
✅ User authenticated: test@example.com
🟢 Setting user ONLINE in Realtime DB: [userId]
✅ User set to ONLINE in Realtime DB: [userId]
✅ onDisconnect handler set for user: [userId]
```

## Step 3: Check Firebase Console

1. **Open Firebase Console**
2. **Go to Realtime Database**
3. **Look at `/presence/{userId}`**
4. **Should show:**
   ```json
   {
     "online": true,
     "lastSeen": 1729558800000
   }
   ```

## Step 4: Test with Second User

1. **Launch second simulator**
2. **Sign in as different user**
3. **Check console** - should see presence set for that user too
4. **Check Firebase** - both users should be online

## If Still Not Working:

### Check 1: Database Rules
In Firebase Console → Realtime Database → Rules:
```json
{
  "rules": {
    "presence": {
      "$userId": {
        ".read": "auth != null",
        ".write": "auth != null && auth.uid == $userId"
      }
    }
  }
}
```

### Check 2: Deploy Rules
```bash
firebase deploy --only database
```

### Check 3: Console Logs
Look for:
- ✅ "User set to ONLINE in Realtime DB"
- ❌ "Failed to set user online" (permission error?)

### Check 4: Manual Test in Firebase Console
1. Go to Realtime Database
2. Click **+** to add data manually
3. Path: `/presence/testuser`
4. Value: `{"online": true}`
5. If this works, rules are fine
6. If this fails, check authentication

## Expected Behavior:

- **On app launch:** User goes online
- **On app background:** User goes offline  
- **On disconnect:** User automatically goes offline (onDisconnect)
- **Green dot** appears next to online users in conversation list

