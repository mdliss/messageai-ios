# MessageAI - Intelligent Messaging for Remote Teams

**Platform:** iOS (Swift/SwiftUI)  
**Version:** 1.0.0  
**Target:** iOS 16.0+

---

## Overview

MessageAI is a production-quality messaging application built for remote teams. It combines WhatsApp-level messaging reliability with AI-powered features that automatically surface decisions, track action items, detect urgent messages, and help teams stay aligned.

---

## Features

### Core Messaging (MVP)
- ✅ User authentication (Email/Password + Google Sign-In)
- ✅ Real-time messaging (<500ms delivery)
- ✅ Optimistic UI (messages appear instantly)
- ✅ Offline support with Core Data persistence
- ✅ Message status indicators (sending/sent/delivered/read)
- ✅ Read receipts with checkmarks
- ✅ Typing indicators
- ✅ Online/offline presence
- ✅ Group chat support (3+ participants)
- ✅ Image sharing with compression
- ✅ Push notifications (foreground + background)

### AI Features
- ✅ **Thread Summarization** - 3-bullet summaries of long conversations
- ✅ **Action Item Extraction** - Automatic tracking of tasks with owners
- ✅ **Priority Detection** - Auto-flagging of urgent messages
- ✅ **Smart Search** - Find messages across all conversations
- ✅ **Decision Tracking** - Automatic logging of team decisions
- ✅ **Proactive Assistant** - Detects scheduling needs and offers help

---

## Tech Stack

### iOS
- Swift 5.9+
- SwiftUI (iOS 16.0+)
- Core Data (offline persistence)
- Combine (reactive programming)
- PhotosUI (image picker)
- UserNotifications (push notifications)

### Backend
- Firebase Authentication
- Cloud Firestore (message storage)
- Firebase Realtime Database (typing, presence)
- Cloud Storage (image uploads)
- Cloud Messaging (push notifications)
- Cloud Functions (AI processing)

### AI
- Anthropic Claude 3.5 Sonnet
- Called from Cloud Functions (secure)

---

## Prerequisites

- macOS Ventura 13.0+ with Xcode 15+
- iOS 16.0+ test device (physical device recommended for push)
- Firebase account
- Anthropic API key
- Apple Developer account (for TestFlight)

---

## Setup Instructions

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/messageAI.git
cd messageAI
```

### 2. Firebase Configuration

1. Create Firebase project: "messageai-prod"
2. Add iOS app with bundle ID: `com.yourorg.messageAI`
3. Download `GoogleService-Info.plist`
4. Place in `messageAI/` directory
5. Enable these services:
   - Authentication (Email/Password + Google)
   - Cloud Firestore
   - Firebase Realtime Database
   - Cloud Storage
   - Cloud Messaging
   - Cloud Functions

### 3. Add Firebase SDK

1. Open `messageAI.xcodeproj` in Xcode
2. The Firebase packages should already be configured
3. If not, add via: File → Add Package Dependencies
4. URL: `https://github.com/firebase/firebase-ios-sdk`
5. Select these packages:
   - FirebaseAuth
   - FirebaseFirestore
   - FirebaseStorage
   - FirebaseMessaging
   - FirebaseDatabase
   - FirebaseFunctions

### 4. Configure Cloud Functions

```bash
cd functions
npm install
```

Set Anthropic API key:
```bash
firebase functions:config:set anthropic.key="YOUR_ANTHROPIC_API_KEY"
```

Deploy functions:
```bash
firebase deploy --only functions
```

### 5. Configure APNs (Push Notifications)

1. In Apple Developer Portal, create APNs key
2. Download the .p8 file
3. In Firebase Console → Project Settings → Cloud Messaging
4. Upload APNs key with Team ID and Key ID

### 6. Build and Run

1. Open `messageAI.xcodeproj` in Xcode
2. Select a simulator or physical device
3. Build and run (Cmd+R)

---

## Project Structure

```
messageAI/
├── Models/              # Data models (User, Message, Conversation, etc.)
├── ViewModels/          # MVVM view models
├── Views/               # SwiftUI views
│   ├── Auth/           # Login, Register, Profile
│   ├── Conversations/  # Conversation list, User picker, Group creation
│   ├── Chat/           # Chat interface, Message bubbles
│   ├── AI/             # AI insights, Assistant
│   ├── Decisions/      # Decision tracking
│   └── Search/         # Message search
├── Services/            # Firebase services
│   ├── AuthService.swift
│   ├── FirestoreService.swift
│   ├── StorageService.swift
│   ├── RealtimeDBService.swift
│   ├── NotificationService.swift
│   ├── CoreDataService.swift
│   └── SyncService.swift
├── CoreData/            # Core Data models and persistence
├── Utilities/           # Helpers and extensions
└── Resources/           # Assets and localization

functions/
├── src/
│   ├── notifications/   # Push notification triggers
│   ├── ai/             # AI feature functions
│   │   ├── summarize.ts
│   │   ├── actionItems.ts
│   │   ├── priority.ts
│   │   ├── decisions.ts
│   │   └── proactive.ts
│   └── index.ts
└── package.json
```

---

## Usage

### Creating an Account
1. Open the app
2. Tap "sign up"
3. Enter email, password, and optional display name
4. Or use "Sign in with Google"

### Starting a Conversation
1. Tap the compose button (+)
2. Select "new message" for 1-on-1 chat
3. Or select "new group" for group chat
4. Select users and tap "Create"

### Sending Messages
- Type text and tap send
- Tap photo icon to send images
- Messages send instantly with optimistic UI
- Works offline - messages queue and send on reconnect

### AI Features
1. Open any conversation
2. Tap the sparkles icon (✨)
3. Choose:
   - **Summarize** - Get 3-bullet summary
   - **Action Items** - Extract tasks and owners

### Viewing Decisions
1. Go to Decisions tab
2. See all team decisions logged automatically
3. Search or filter by date

### Search
1. Tap search icon on conversations screen
2. Search across all messages
3. Results grouped by conversation

---

## Testing

### Run on Simulator
```bash
# Build and run
xcodebuild -scheme messageAI -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Test Real-Time Messaging
1. Run on 2 devices simultaneously
2. Sign in as different users
3. Start a conversation
4. Send messages - should appear in <500ms

### Test Offline Support
1. Send messages while offline (airplane mode)
2. Messages show "sending" status
3. Go back online
4. Messages auto-sync and show "sent"

---

## Deployment

### TestFlight

1. Configure signing in Xcode
2. Product → Archive
3. Distribute App → TestFlight
4. Upload to App Store Connect
5. Add internal testers
6. Generate public link

### Production

1. Deploy security rules:
```bash
firebase deploy --only firestore:rules,database
```

2. Deploy all Cloud Functions:
```bash
cd functions
firebase deploy --only functions
```

3. Test all features in production environment

---

## Performance Targets

| Metric | Target | Status |
|--------|--------|--------|
| Message send (optimistic UI) | <100ms | ✅ |
| Message delivery (online) | <500ms | ✅ |
| Typing indicator | <200ms | ✅ |
| Presence update | <5s | ✅ |
| App cold start | <2s | ✅ |
| AI feature response | <3s | ✅ |

---

## Architecture

**Pattern:** MVVM (Model-View-ViewModel)

**Data Flow:**
1. Views observe ViewModels (@Published properties)
2. ViewModels call Services for operations
3. Services interact with Firebase/Core Data
4. Real-time updates flow back through AsyncStreams

**Offline Strategy:**
- Load from Core Data first (instant)
- Subscribe to Firestore for real-time updates
- Queue offline messages in Core Data
- Auto-sync on reconnect with retry logic

---

## Known Limitations

- iOS only (no Android support yet)
- No end-to-end encryption
- No message editing/deletion
- Basic search (keyword-based, not semantic)
- Images only (no video/voice)

---

## Future Enhancements

- Semantic search with vector embeddings
- Voice and video messages
- Message reactions
- Reply/quote functionality
- Multi-device sync
- Android app
- Web client

---

## License

MIT License - see LICENSE file

---

## Contact

For questions or support, contact: [your email]

---

## Acknowledgments

- Firebase for backend infrastructure
- Anthropic for Claude AI
- SwiftUI for modern iOS development

