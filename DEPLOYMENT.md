# MessageAI - Deployment Guide

Step-by-step instructions for deploying MessageAI to production.

---

## Pre-Deployment Checklist

### iOS App
- [ ] All files added to Xcode target
- [ ] Core Data model created in Xcode
- [ ] GoogleService-Info.plist added (not in git)
- [ ] Info.plist configured with URL scheme
- [ ] Firebase packages installed
- [ ] App builds without errors
- [ ] Tested on simulator
- [ ] Tested on physical device

### Firebase
- [ ] Firebase project created
- [ ] Authentication enabled (Email/Password + Google)
- [ ] Firestore database created
- [ ] Realtime Database created
- [ ] Cloud Storage enabled
- [ ] Cloud Messaging enabled
- [ ] APNs certificate uploaded

### Cloud Functions
- [ ] Node.js 18 installed
- [ ] Dependencies installed (`npm install`)
- [ ] Anthropic API key configured
- [ ] Functions build successfully (`npm run build`)

---

## Step 1: Deploy Firebase Security Rules

### Firestore Rules
```bash
firebase deploy --only firestore:rules
```

### Realtime Database Rules
```bash
firebase deploy --only database
```

### Verify Rules
Test with unauthenticated user - should get permission denied.

---

## Step 2: Deploy Cloud Functions

### Configure API Key
```bash
cd functions
firebase functions:config:set anthropic.key="YOUR_ANTHROPIC_API_KEY"
```

### Install Dependencies
```bash
npm install
```

### Build TypeScript
```bash
npm run build
```

### Deploy All Functions
```bash
firebase deploy --only functions
```

Or deploy individually:
```bash
firebase deploy --only functions:sendMessageNotification
firebase deploy --only functions:summarizeConversation
firebase deploy --only functions:extractActionItems
firebase deploy --only functions:detectPriority
firebase deploy --only functions:detectDecision
firebase deploy --only functions:detectProactiveSuggestions
```

### Verify Deployment
Check Firebase Console → Functions to see all deployed.

---

## Step 3: Configure APNs for Push Notifications

### Create APNs Key
1. Go to Apple Developer Portal
2. Certificates, Identifiers & Profiles
3. Keys → Create new key
4. Enable Apple Push Notifications service (APNs)
5. Download .p8 file (SAVE IT - can't re-download)
6. Note the Key ID and Team ID

### Upload to Firebase
1. Firebase Console → Project Settings
2. Cloud Messaging tab
3. iOS app configuration
4. Upload APNs key:
   - Select .p8 file
   - Enter Key ID
   - Enter Team ID
5. Save

### Test Push Notifications
Must test on physical device (simulator unreliable for push).

---

## Step 4: Prepare iOS App for TestFlight

### Configure App Settings
1. In Xcode, select project
2. Select messageAI target
3. General tab:
   - Version: 1.0.0
   - Build: 1
   - Bundle Identifier: com.yourorg.messageAI

### Configure Signing
1. Signing & Capabilities tab
2. Automatically manage signing: ON
3. Team: Select your Apple Developer team
4. Ensure capabilities are enabled:
   - Push Notifications
   - Background Modes → Remote notifications

### Add App Icons
1. Create app icons (all required sizes)
2. Add to Assets.xcassets/AppIcon
3. Or use online tool: https://appicon.co

---

## Step 5: Create Archive

### Build for Release
1. Select "Any iOS Device" as destination
2. Product → Archive
3. Wait for archiving to complete
4. Organizer window opens automatically

### Validate Archive
1. In Organizer, select the archive
2. Click "Validate App"
3. Follow prompts
4. Fix any validation errors

---

## Step 6: Submit to TestFlight

### Distribute
1. In Organizer, click "Distribute App"
2. Select "TestFlight & App Store"
3. Next → Next → Upload
4. Wait for processing (10-30 minutes)

### Add Testers
1. App Store Connect → TestFlight
2. Add yourself as Internal Tester
3. Or create External Testing group
4. Generate public link

### Test Installation
1. Install TestFlight app on iPhone
2. Open TestFlight link
3. Install MessageAI
4. Test all features

---

## Step 7: Production Testing

### Test Checklist
- [ ] Sign up with new account
- [ ] Sign in with existing account
- [ ] Google Sign-In works
- [ ] Create conversation
- [ ] Send text messages (real-time)
- [ ] Send images
- [ ] Messages work offline
- [ ] Reconnect - messages sync
- [ ] Group chat works
- [ ] Read receipts update
- [ ] Typing indicators show
- [ ] Online status accurate
- [ ] Push notifications arrive
- [ ] AI Summarization works
- [ ] AI Action Items work
- [ ] Priority detection works
- [ ] Search works
- [ ] Decisions logged

### Multi-User Test
1. Install on 2 devices
2. Sign in as different users
3. Start conversation
4. Send messages simultaneously
5. Verify real-time sync

### Offline Test
1. Enable airplane mode
2. Send 5 messages
3. Close app
4. Disable airplane mode
5. Reopen app
6. Verify all 5 messages sent

---

## Step 8: Create Demo Video

### Script (5-7 minutes)
1. **Intro (30s):** What is MessageAI, who it's for
2. **MVP Demo (2 min):**
   - Show authentication
   - Create conversation
   - Send messages (2 devices side-by-side)
   - Show real-time sync
   - Demonstrate offline mode
   - Show group chat
   - Send images
3. **AI Features (3 min):**
   - Summarize long thread
   - Extract action items
   - Show priority message
   - Search for message
   - View decisions tab
   - Demonstrate proactive assistant
4. **Conclusion (30s):**
   - Tech stack recap
   - Challenges overcome
   - Future roadmap

### Recording
- Use 2 iPhones side-by-side
- Screen record both (QuickTime on Mac)
- Professional narration
- Edit with transitions
- Add callouts/annotations

### Upload
- YouTube (unlisted)
- Loom
- Get shareable link

---

## Step 9: Final Submission

### GitHub Repository
Ensure repo includes:
- All source code
- README.md
- PERSONA.md
- architecture.md
- PRD.md
- tasks.md
- .gitignore (no secrets)

### Make Public
```bash
# If private repo
gh repo edit --visibility public
```

### Links to Include
- GitHub repo URL
- TestFlight public link
- Demo video URL

---

## Troubleshooting

### Build Fails
1. Clean build folder (Shift+Cmd+K)
2. Delete DerivedData
3. Restart Xcode
4. Check all files in target membership

### Push Notifications Don't Work
- Must test on physical device
- Check APNs certificate in Firebase
- Verify capabilities enabled in Xcode
- Check FCM token is being saved

### Cloud Functions Fail
- Check logs: `firebase functions:log`
- Verify Anthropic API key set
- Check function deploy status in console
- Test with emulator first

### Firestore Permission Denied
- Deploy rules: `firebase deploy --only firestore:rules`
- Check user is authenticated
- Verify participantIds includes user

---

## Cost Monitoring

### Firebase Free Tier Limits
- Firestore: 50k reads/day, 20k writes/day
- Storage: 5GB, 1GB downloads/day
- Functions: 125k invocations/day
- Realtime DB: 100 simultaneous connections

### Set Budget Alerts
1. Firebase Console → Usage and billing
2. Set budget: $10
3. Get email alerts at 50%, 90%, 100%

### Optimize Costs
- Use Core Data caching aggressively
- Limit Firestore queries
- Use Realtime DB for ephemeral data
- Compress images before upload

---

## Support

For issues, check:
1. Firebase Console → Functions → Logs
2. Xcode Console for iOS errors
3. Firebase Status: https://status.firebase.google.com

Good luck with deployment! 🚀

