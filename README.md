# MessageAI

> an AI powered messaging app for remote team professionals

MessageAI helps distributed teams cut through communication noise with intelligent features like thread summarization, action item extraction, priority detection, decision tracking, and proactive scheduling assistance.

## Features

### Core Messaging
- **Real Time Chat**: Sub 200ms message delivery with optimistic UI
- **Offline Support**: Queue messages when offline, auto sync on reconnect within 1 second
- **Group Conversations**: Support for 3+ participants with read receipts and typing indicators
- **Image Sharing**: Send photos with automatic compression and storage
- **Presence Indicators**: See who's online in real time

### AI Powered Features

#### 1. Thread Summarization ✨
Get conversation summaries in 3 bullet points. Perfect for catching up on long discussions.
- **Privacy**: Summaries only visible to requester
- **Focus**: Key decisions, action items, and blockers
- **Speed**: Results in under 3 seconds

#### 2. Action Item Extraction 📋
Automatically extract tasks with owners and deadlines from conversations.
- **Intelligent Detection**: Finds commitments, assignments, and follow ups
- **Structured Format**: Clear task descriptions with responsible parties
- **Source Linking**: Jump back to original message context

#### 3. Priority Detection 🚨
Urgent messages automatically flagged with visual indicators.
- **Smart Signals**: Detects ASAP, deadlines, @mentions, and urgency keywords
- **Accuracy**: 85%+ correct flagging rate
- **Filter View**: See only high priority messages

#### 4. Decision Tracking 📌
Team decisions automatically logged and organized.
- **Pattern Recognition**: Identifies consensus phrases and poll results
- **Timeline View**: Chronological history of all decisions
- **Context Preservation**: Links to original discussion

#### 5. Proactive Scheduling Assistant 🗓️
AI suggests meeting times based on participant timezones and availability.
- **Timezone Aware**: Respects work hours across global teams
- **One Tap Polls**: Create voting polls from suggested times
- **Smart Detection**: Recognizes scheduling intent in conversations

## Tech Stack

- **Client**: Swift, SwiftUI, Core Data (iOS 16+)
- **Backend**: Firebase (Firestore, Realtime Database, Auth, Cloud Functions, Storage, FCM)
- **AI**: OpenAI GPT-4 via Cloud Functions
- **Architecture**: MVVM, Offline First, Real Time Sync

## Prerequisites

- **macOS**: 13.0 (Ventura) or later
- **Xcode**: 15.0 or later
- **iOS Deployment Target**: 16.0 or later
- **CocoaPods**: 1.12.0 or later
- **Node.js**: 18.0 or later (for Cloud Functions)
- **Firebase CLI**: `npm install -g firebase-tools`
- **Firebase Project**: Set up at [console.firebase.google.com](https://console.firebase.google.com)

## Installation

### 1. Clone Repository
```bash
git clone https://github.com/yourusername/messageai-ios.git
cd messageai-ios
```

### 2. Firebase Setup

#### Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create new project or select existing
3. Add iOS app with bundle ID: `com.messageai.app` (or your custom ID)
4. Download `GoogleService-Info.plist`

#### Configure Firebase Services
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize project
firebase init

# Select:
# - Firestore
# - Realtime Database
# - Functions
# - Storage
# - Hosting (optional)
```

#### Set Up Authentication
1. Firebase Console → Authentication → Sign-in method
2. Enable **Email/Password**
3. (Optional) Enable **Google Sign-In**

#### Configure Firestore
```bash
# Deploy Firestore rules and indexes
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

#### Set Up Realtime Database
1. Firebase Console → Realtime Database → Create Database
2. Start in **test mode** (development) or use production rules:
```json
{
  "rules": {
    "presence": {
      "$uid": {
        ".read": true,
        ".write": "$uid === auth.uid"
      }
    },
    "typing": {
      "$conversationId": {
        "$uid": {
          ".read": true,
          ".write": "$uid === auth.uid"
        }
      }
    }
  }
}
```

#### Configure Storage
1. Firebase Console → Storage → Get Started
2. Deploy storage rules:
```bash
firebase deploy --only storage
```

### 3. Cloud Functions Setup

#### Install Dependencies
```bash
cd functions
npm install
```

#### Configure AI API Keys
```bash
# Set OpenAI API key (required for AI features)
firebase functions:config:set openai.key="sk-..."

# Optional: Set other AI provider keys
firebase functions:config:set perplexity.key="pplx-..."
```

#### Deploy Functions
```bash
# Deploy all functions
firebase deploy --only functions

# Or deploy specific functions
firebase deploy --only functions:summarizeConversation
firebase deploy --only functions:extractActionItems
firebase deploy --only functions:detectPriority
firebase deploy --only functions:detectDecision
firebase deploy --only functions:detectProactiveSuggestions
```

### 4. iOS App Setup

#### Install CocoaPods Dependencies
```bash
cd ..
pod install
```

#### Add GoogleService-Info.plist
1. Place downloaded `GoogleService-Info.plist` in `messageAI/` directory
2. Ensure it's added to target in Xcode

#### Configure Bundle ID
1. Open `messageAI.xcworkspace` (NOT .xcodeproj)
2. Select project → Target → Signing & Capabilities
3. Update bundle identifier to match Firebase iOS app
4. Select development team for code signing

#### Update Firebase Config (if needed)
If using custom Firebase project, verify `Firebaseconfig.swift` has correct settings.

### 5. Build and Run

#### Using Xcode
1. Open `messageAI.xcworkspace`
2. Select target device or simulator (iOS 16+)
3. Press `Cmd + R` to build and run

#### Using Command Line
```bash
# Build
xcodebuild -workspace messageAI.xcworkspace \
           -scheme messageAI \
           -configuration Debug \
           -destination 'platform=iOS Simulator,name=iPhone 15' \
           build

# Run on simulator
xcrun simctl boot "iPhone 15"
xcrun simctl install booted <path-to-app>
xcrun simctl launch booted com.messageai.app
```

## Configuration

### Environment Variables

#### Cloud Functions
Set via Firebase CLI:
```bash
firebase functions:config:set \
  openai.key="sk-..." \
  perplexity.key="pplx-..." \
  anthropic.key="sk-ant-..."
```

#### iOS App (Optional)
Create `Config.xcconfig` for local development overrides (do not commit):
```
FIREBASE_PROJECT_ID = your-project-id
APP_BUNDLE_ID = com.messageai.app
```

### Firestore Indexes

Composite indexes are defined in `firestore.indexes.json`. Deploy with:
```bash
firebase deploy --only firestore:indexes
```

If you see index errors in logs, Firebase will provide a direct link to create the index.

## Usage

### Creating an Account
1. Launch app on simulator or device
2. Tap **Register**
3. Enter email and password
4. Tap **Create Account**

### Starting a Conversation
1. Tap **+** button in conversations list
2. Select user from list
3. Start messaging!

### Creating a Group Chat
1. Tap **+** button → **New Group**
2. Select 3+ participants
3. (Optional) Set group name
4. Tap **Create**

### Using AI Features
1. Open any conversation
2. Tap **✨** button in toolbar
3. Select desired feature:
   - **Summarize**: Get 3 bullet summary
   - **Action Items**: Extract tasks
   - **Priority Detection**: Auto flagged in messages
   - **Decisions**: Auto logged to Decisions tab

### Proactive Scheduling
1. In group chat, mention meeting/scheduling
   - Example: "let's schedule a meeting tomorrow"
2. AI will suggest optimal times based on timezones
3. Tap **Create Poll** to send voting poll to group
4. Participants vote inline, results auto update

## Testing

### Manual Testing Scenarios

#### Real Time Messaging
1. Open app on 2 simulators with different accounts
2. Send messages rapidly (20+ in 30 seconds)
3. Verify delivery <200ms, typing indicators work

#### Offline Support
1. Enable airplane mode on device
2. Send 5 messages (should queue locally)
3. Disable airplane mode
4. Verify all messages sync within 1 second

#### Group Chat
1. Create group with 3+ users
2. Test typing indicators, read receipts
3. Verify presence shows correctly

#### AI Features
1. Have a 20+ message conversation
2. Request summary
3. Verify appears only on requesting user's device
4. Extract action items, verify format

### Automated Tests
```bash
# Run unit tests
xcodebuild test -workspace messageAI.xcworkspace \
                -scheme messageAI \
                -destination 'platform=iOS Simulator,name=iPhone 15'

# Run UI tests
xcodebuild test -workspace messageAI.xcworkspace \
                -scheme messageAIUITests \
                -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Troubleshooting

### Build Errors

#### "GoogleService-Info.plist not found"
- Ensure file is in `messageAI/` directory
- Check it's added to target in Xcode → File Inspector

#### "Pod install failed"
```bash
# Clear CocoaPods cache
pod cache clean --all
rm -rf Pods/
rm Podfile.lock
pod install
```

#### "Code signing failed"
- Select development team in Xcode
- Or use automatic signing

### Runtime Errors

#### "Messages not syncing"
- Check Firestore rules allow user access
- Verify network connection
- Check console for authentication errors

#### "AI features not working"
```bash
# Verify API key is set
firebase functions:config:get

# Check function logs
firebase functions:log --only summarizeConversation

# Redeploy functions
firebase deploy --only functions
```

#### "Presence shows everyone offline"
- Verify Realtime Database rules
- Check database URL in `Firebaseconfig.swift`
- Look for RTDB connection errors in console

#### "Images not uploading"
- Verify Storage rules allow authenticated writes
- Check storage bucket configuration
- Ensure network connection

### Performance Issues

#### "Slow message delivery"
- Check network latency (Settings → Network Link Conditioner)
- Verify Firestore indexes are deployed
- Look for large message history slowing queries

#### "App crashes on large conversations"
- Reduce message fetch limit in `ChatViewModel`
- Implement message pagination
- Clear Core Data cache

## Project Structure

```
messageai-ios-fresh/
├── messageAI/                 # iOS App
│   ├── Models/               # Data models
│   ├── Services/             # Firebase, Core Data, Network
│   ├── ViewModels/           # MVVM view models
│   ├── Views/                # SwiftUI views
│   │   ├── Auth/            # Login, Register
│   │   ├── Chat/            # Messaging UI
│   │   ├── Conversations/   # Conversation list
│   │   ├── AI/              # AI insights
│   │   └── Decisions/       # Decision tracking
│   ├── Utilities/            # Helpers, Extensions
│   ├── CoreData/            # Local persistence
│   └── GoogleService-Info.plist
├── functions/                # Cloud Functions
│   ├── src/
│   │   ├── ai/              # AI feature functions
│   │   ├── notifications/   # Push notifications
│   │   └── index.ts         # Function exports
│   └── package.json
├── firestore.rules           # Security rules
├── firestore.indexes.json    # Composite indexes
├── storage.rules             # Storage security
├── database.rules.json       # RTDB rules
└── docs/                     # Documentation
    ├── ARCHITECTURE.md       # System design
    └── PRD.md               # Product requirements
```

## Contributing

### Development Workflow
1. Create feature branch: `git checkout -b feature/name`
2. Make changes and test thoroughly
3. Run linter: `swiftlint` (iOS), `npm run lint` (Functions)
4. Commit with clear message
5. Push and create pull request

### Code Style
- **Swift**: Follow [Swift Style Guide](https://google.github.io/swift/)
- **TypeScript**: ESLint configuration in `functions/.eslintrc.js`
- **Naming**: Use descriptive variable names, avoid abbreviations
- **Comments**: Explain complex logic, document public APIs

### Testing Requirements
- Add unit tests for new services and view models
- Update UI tests for new user flows
- Manually test on physical device before PR
- Verify offline scenarios work

## License

MIT License. See [LICENSE](LICENSE) for details.

## Contact

- **Issues**: [GitHub Issues](https://github.com/yourusername/messageai-ios/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/messageai-ios/discussions)
- **Email**: support@messageai.app

## Acknowledgments

- Firebase for backend infrastructure
- OpenAI for GPT-4 AI capabilities
- Swift and SwiftUI community

---

**Built with ❤️ for remote teams everywhere**
