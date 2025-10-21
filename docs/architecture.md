# MessageAI MVP - Architecture Document (iOS Native)

**Project**: MessageAI - Real-Time Messaging with AI Features  
**Platform**: iOS (Swift/SwiftUI)  
**Goal**: Build production-quality messaging infrastructure with intelligent AI capabilities  
**Persona**: Remote Team Professional  
**Timeline**: 7-day sprint with 24-hour MVP checkpoint

---

## System Architecture Diagram

```mermaid
graph TB
    subgraph "iOS App - Swift + SwiftUI"
        subgraph "View Layer"
            AuthViews[Auth Views<br/>LoginView/RegisterView]
            ConvList[ConversationsView<br/>Home Screen]
            ChatView[ChatView<br/>Messages + AI]
            AIAssistant[AIAssistantView<br/>Dedicated Chat]
            ProfileView[ProfileView]
        end

        subgraph "ViewModels - MVVM"
            AuthVM[AuthViewModel<br/>User State]
            ConvVM[ConversationsViewModel<br/>Conversation List]
            ChatVM[ChatViewModel<br/>Messages/Typing]
            AIVM[AIInsightsViewModel<br/>AI Features]
        end

        subgraph "Services Layer"
            AuthSvc[AuthService<br/>Firebase Auth]
            FirestoreSvc[FirestoreService<br/>CRUD Operations]
            StorageSvc[StorageService<br/>Image Upload]
            NotifSvc[NotificationService<br/>APNs Setup]
            PresenceSvc[PresenceService<br/>Online Status]
        end

        subgraph "Local Storage"
            CoreData[(Core Data<br/>Message Persistence<br/>Offline Support)]
            SyncQueue[SyncQueue<br/>Pending Messages]
        end

        subgraph "Managers"
            NetworkMgr[NetworkManager<br/>Reachability]
            SyncMgr[SyncManager<br/>Offline Queue]
        end
    end

    subgraph "Firebase Backend"
        subgraph "Firebase Services"
            FBAuth[Firebase Auth<br/>Email/Password/Google]
            APNs[APNs<br/>Push Notifications]
        end

        subgraph "Cloud Firestore"
            Users[(users<br/>User Profiles)]
            Conversations[(conversations<br/>Metadata)]
            Messages[(conversations/{id}/messages<br/>Message History)]
            Insights[(conversations/{id}/insights<br/>AI-Generated)]
            Typing[(conversations/{id}/typing<br/>Ephemeral)]
        end

        subgraph "Cloud Functions"
            OnMessage[onMessageCreated<br/>Priority Detection]
            AISum[summarizeConversation<br/>Thread Summary]
            AIAction[extractActionItems<br/>Task Extraction]
            AIProactive[detectProactiveSuggestions<br/>Scheduling Hints]
            NotifFunc[sendMessageNotification<br/>Push to Offline Users]
        end

        subgraph "AI Integration"
            Claude[Anthropic Claude 3.5<br/>LLM Processing]
            RAG[RAG Pipeline<br/>Context Retrieval]
        end
    end

    %% View to ViewModel connections
    AuthViews --> AuthVM
    ConvList --> ConvVM
    ChatView --> ChatVM
    AIAssistant --> AIVM

    %% ViewModel to Services
    AuthVM --> AuthSvc
    ConvVM --> FirestoreSvc
    ChatVM --> FirestoreSvc
    ChatVM --> PresenceSvc
    AIVM --> FirestoreSvc

    %% Services to Local Storage
    FirestoreSvc --> CoreData
    FirestoreSvc --> SyncQueue
    NotifSvc --> APNs

    %% Services to Firebase
    AuthSvc --> FBAuth
    FirestoreSvc --> Users
    FirestoreSvc --> Conversations
    FirestoreSvc --> Messages
    FirestoreSvc --> Insights
    FirestoreSvc --> Typing

    %% Real-time sync paths
    Messages -->|Real-time listener<br/>onSnapshot<br/>under 500ms| ChatVM
    ChatVM -->|Optimistic update<br/>under 100ms| CoreData
    
    SyncQueue -->|On reconnect<br/>Retry pending| SyncMgr
    SyncMgr -->|Upload| FirestoreSvc
    
    Typing -->|Real-time listener<br/>TTL 10s| ChatVM

    %% Cloud Function triggers
    Messages -->|onCreate trigger| OnMessage
    Messages -->|onCreate trigger| NotifFunc
    OnMessage -->|Priority flag| Messages
    NotifFunc -->|Push| APNs

    %% AI function calls
    AISum -->|RAG retrieval| Messages
    AISum -->|LLM call| Claude
    Claude -->|Insight| Insights

    AIAction -->|RAG retrieval| Messages
    AIAction -->|LLM call| Claude

    AIProactive -->|Pattern match| Messages
    AIProactive -->|Suggestion| Insights

    %% User interactions
    User([Users<br/>iPhone/iPad]) -->|Interact| AuthViews
    User -->|Interact| ConvList
    User -->|Interact| ChatView

    %% Network monitoring
    NetworkMgr -->|Monitor| SyncMgr

    %% Styling
    classDef ios fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef firebase fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    classDef ai fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    classDef storage fill:#e8f5e9,stroke:#388e3c,stroke-width:2px
    classDef user fill:#fce4ec,stroke:#c2185b,stroke-width:3px

    class AuthViews,ConvList,ChatView,AIAssistant,ProfileView,AuthVM,ConvVM,ChatVM,AIVM,AuthSvc,FirestoreSvc,StorageSvc,NotifSvc,PresenceSvc,NetworkMgr,SyncMgr ios
    class FBAuth,APNs,Users,Conversations,Messages,Insights,Typing,OnMessage,AISum,AIAction,AIProactive,NotifFunc firebase
    class Claude,RAG ai
    class CoreData,SyncQueue storage
    class User user
```

---

## iOS Architecture Pattern: MVVM + Services

### MVVM Structure

**Views (SwiftUI)**
- Declarative UI components
- Observe ViewModels via `@ObservedObject` or `@StateObject`
- No business logic
- Pure presentation layer

**ViewModels (ObservableObject)**
- Business logic and state management
- Publish state changes via `@Published` properties
- Call Services for data operations
- Handle user interactions

**Services (Singleton pattern)**
- Firebase operations
- Core Data operations
- Network calls
- Device APIs (camera, notifications)

### Why MVVM for This Project

1. **SwiftUI Native**: MVVM is SwiftUI's natural pattern
2. **Testability**: ViewModels can be unit tested without UI
3. **Reusability**: Services shared across ViewModels
4. **Reactive**: Combine framework for real-time updates
5. **Offline-First**: Core Data + Firestore sync cleanly separated

---

## Messaging Architecture (MVP)

**Real-Time Sync Strategy:**

- Optimistic UI: Messages appear instantly (<100ms) before server confirmation
- Local-first: All messages stored in Core Data for offline access
- Firestore listeners: Real-time updates from other users (<500ms)
- Sync queue: Pending messages retry on reconnect
- No message ever lost: Core Data crash-safe persistence

**Offline Handling:**

- Send while offline: Queue in Core Data with `status = .sending`
- Receive while offline: Messages accumulate in Firestore
- On reconnect: Auto-sync pending sends + fetch missed messages
- Conflict resolution: Append-only (no conflicts possible)

**Navigation Structure:**

- SwiftUI NavigationStack with enum-based routing
- `/` - ConversationsView (authenticated)
- `/conversation/:id` - ChatView with messages
- `/ai-assistant` - Dedicated AI chat interface
- `/profile` - User settings

---

## Data Models

### Firestore Collection: `/users/{userId}`

```swift
struct User: Codable, Identifiable {
    let id: String
    let email: String
    let displayName: String
    let photoURL: String?
    var isOnline: Bool
    var lastSeen: Date
    var fcmToken: String?
    let createdAt: Date
    var preferences: UserPreferences
}

struct UserPreferences: Codable {
    var aiEnabled: Bool = true
    var notificationSettings: [String: Bool] = [:]
}
```

### Firestore Collection: `/conversations/{conversationId}`

```swift
struct Conversation: Codable, Identifiable {
    let id: String
    let type: ConversationType
    let participantIds: [String]
    var participantDetails: [String: ParticipantDetail]
    var lastMessage: LastMessage?
    var unreadCount: [String: Int]
    let createdAt: Date
    var updatedAt: Date
    
    // Group chat specific
    var groupName: String?
    var groupPhotoURL: String?
    var adminIds: [String]?
}

enum ConversationType: String, Codable {
    case direct
    case group
}

struct ParticipantDetail: Codable {
    let displayName: String
    let photoURL: String?
}

struct LastMessage: Codable {
    let text: String
    let senderId: String
    let timestamp: Date
}
```

### Firestore Subcollection: `/conversations/{id}/messages/{messageId}`

```swift
struct Message: Codable, Identifiable {
    let id: String
    let conversationId: String
    let senderId: String
    let senderName: String
    let senderPhotoURL: String?
    
    let type: MessageType
    let text: String
    let imageURL: String?
    
    let createdAt: Date
    
    var status: MessageStatus
    var deliveredTo: [String]
    var readBy: [String]
    
    let localId: String?
    var isSynced: Bool
    var priority: Bool?
}

enum MessageType: String, Codable {
    case text
    case image
}

enum MessageStatus: String, Codable {
    case sending
    case sent
    case delivered
    case read
    case failed
}
```

### Firestore Subcollection: `/conversations/{id}/insights/{insightId}`

```swift
struct AIInsight: Codable, Identifiable {
    let id: String
    let conversationId: String
    let type: InsightType
    let content: String
    let metadata: InsightMetadata?
    let messageIds: [String]
    let triggeredBy: String
    let createdAt: Date
    let expiresAt: Date?
    var userFeedback: String?
    var dismissed: Bool
}

enum InsightType: String, Codable {
    case summary
    case actionItems = "action_items"
    case decision
    case priority
    case suggestion
}

struct InsightMetadata: Codable {
    var bulletPoints: Int?
    var messageCount: Int?
    var approvedBy: [String]?
    var action: String?
    var confidence: Double?
}
```

### Firestore Subcollection: `/conversations/{id}/typing/{userId}`

```swift
struct TypingIndicator: Codable, Identifiable {
    let userId: String
    let conversationId: String
    var isTyping: Bool
    let timestamp: Date
    
    var id: String { userId }
}
```

---

## Core Data Schema

### Entity: `MessageEntity`

```swift
@objc(MessageEntity)
public class MessageEntity: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var conversationId: String
    @NSManaged public var senderId: String
    @NSManaged public var senderName: String
    @NSManaged public var senderPhotoURL: String?
    
    @NSManaged public var type: String
    @NSManaged public var text: String
    @NSManaged public var imageURL: String?
    
    @NSManaged public var createdAt: Date
    
    @NSManaged public var status: String
    @NSManaged public var deliveredTo: String? // JSON array
    @NSManaged public var readBy: String? // JSON array
    
    @NSManaged public var localId: String?
    @NSManaged public var isSynced: Bool
    @NSManaged public var priority: Bool
    
    @NSManaged public var conversation: ConversationEntity?
}
```

### Entity: `ConversationEntity`

```swift
@objc(ConversationEntity)
public class ConversationEntity: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var type: String
    @NSManaged public var participantIds: String // JSON array
    @NSManaged public var participantDetails: String? // JSON object
    @NSManaged public var lastMessageText: String?
    @NSManaged public var lastMessageTimestamp: Date?
    @NSManaged public var unreadCount: Int32
    @NSManaged public var updatedAt: Date
    
    @NSManaged public var messages: NSSet?
}
```

---

## Tech Stack

### iOS Native Stack

**Frontend:**
- Swift 5.9+
- SwiftUI (iOS 16.0+)
- Combine (reactive programming)
- Core Data (local persistence)
- PhotosUI (image picker)
- UserNotifications (push notifications)

**Backend:**
- Firebase Authentication (email/password + Google Sign-In)
- Cloud Firestore (real-time messages)
- Cloud Functions (AI processing, Node.js)
- Cloud Messaging (APNs integration)
- Cloud Storage (image uploads)

**AI Layer:**
- Anthropic Claude 3.5 Sonnet
- Called from Cloud Functions (keeps API keys secure)

**Dependencies (Swift Package Manager):**
- Firebase iOS SDK (10.0+)
- GoogleSignIn-iOS
- SDWebImageSwiftUI (image caching)

**Pros:**
- Native iOS performance
- SwiftUI provides modern, declarative UI
- Core Data battle-tested for offline
- Firebase real-time sync purpose-built for messaging
- Single platform focus for 7-day sprint
- TestFlight for easy beta testing

**Cons:**
- iOS only (no Android for MVP)
- Requires macOS with Xcode
- Learning curve if new to SwiftUI
- Firestore charges per read/write

---

## Project File Structure

```
MessageAI/
├── MessageAI.xcodeproj
├── MessageAI/
│   ├── MessageAIApp.swift          # App entry point
│   ├── Info.plist
│   ├── GoogleService-Info.plist    # Firebase config
│   │
│   ├── Models/
│   │   ├── User.swift
│   │   ├── Conversation.swift
│   │   ├── Message.swift
│   │   ├── AIInsight.swift
│   │   └── TypingIndicator.swift
│   │
│   ├── ViewModels/
│   │   ├── AuthViewModel.swift
│   │   ├── ConversationsViewModel.swift
│   │   ├── ChatViewModel.swift
│   │   └── AIInsightsViewModel.swift
│   │
│   ├── Views/
│   │   ├── Auth/
│   │   │   ├── LoginView.swift
│   │   │   └── RegisterView.swift
│   │   ├── Conversations/
│   │   │   ├── ConversationsView.swift
│   │   │   └── ConversationRow.swift
│   │   ├── Chat/
│   │   │   ├── ChatView.swift
│   │   │   ├── MessageBubble.swift
│   │   │   ├── MessageInputView.swift
│   │   │   └── TypingIndicatorView.swift
│   │   ├── AI/
│   │   │   ├── AIAssistantView.swift
│   │   │   ├── AIInsightCard.swift
│   │   │   └── DecisionsView.swift
│   │   └── Profile/
│   │       └── ProfileView.swift
│   │
│   ├── Services/
│   │   ├── Firebase/
│   │   │   ├── FirebaseService.swift
│   │   │   ├── AuthService.swift
│   │   │   ├── FirestoreService.swift
│   │   │   ├── StorageService.swift
│   │   │   └── PresenceService.swift
│   │   ├── CoreDataService.swift
│   │   ├── NotificationService.swift
│   │   └── ImageService.swift
│   │
│   ├── Managers/
│   │   ├── NetworkManager.swift
│   │   └── SyncManager.swift
│   │
│   ├── Utilities/
│   │   ├── Constants.swift
│   │   ├── Extensions/
│   │   │   ├── Date+Extensions.swift
│   │   │   ├── String+Extensions.swift
│   │   │   └── View+Extensions.swift
│   │   └── Helpers/
│   │       └── ImageCompressor.swift
│   │
│   ├── CoreData/
│   │   ├── MessageAI.xcdatamodeld
│   │   └── PersistenceController.swift
│   │
│   └── Resources/
│       ├── Assets.xcassets
│       └── Localizable.strings
│
├── functions/                       # Firebase Cloud Functions
│   ├── src/
│   │   ├── index.ts
│   │   ├── ai/
│   │   │   ├── summarize.ts
│   │   │   ├── actionItems.ts
│   │   │   ├── priority.ts
│   │   │   ├── decisions.ts
│   │   │   └── proactive.ts
│   │   └── notifications/
│   │       └── sendMessage.ts
│   ├── package.json
│   └── tsconfig.json
│
├── .gitignore
├── README.md
├── architecture.md
├── PRD.md
└── tasks.md
```

---

## Real-Time Synchronization Strategy

### Message Send Flow (Optimistic UI)

1. **User taps "Send":**
   - Generate local UUID (`UUID().uuidString`)
   - Create `MessageEntity` in Core Data with `status = .sending`, `isSynced = false`
   - Render message bubble immediately (< 100ms)
   - Show clock icon (sending indicator)

2. **Background upload:**
   - `FirestoreService` writes to `/conversations/{id}/messages`
   - Firestore auto-generates server ID
   - Update conversation's `lastMessage` and `updatedAt`

3. **Server confirmation:**
   - Firestore listener fires with new message
   - Match by `localId` → update Core Data with server ID
   - Change status: `.sending` → `.sent`
   - Update UI: clock icon → checkmark

4. **Recipients receive:**
   - Their Firestore listeners fire
   - Insert to local Core Data
   - Update UI with new message
   - Send read receipt if conversation is active

5. **Read receipts:**
   - Update `readBy` array in Firestore message doc
   - Sender's listener updates UI: checkmark → double checkmark → blue double checkmark

### Offline Message Queue

**Sending while offline:**
- Messages stay in Core Data with `isSynced = false`
- `SyncManager` tracks pending uploads
- UI shows persistent "sending" indicator

**On reconnect:**
- `NetworkManager` detects network state change
- `SyncManager` queries Core Data for `isSynced = false`
- Retry Firestore upload in order (FIFO)
- Update each message on success

**Failure handling:**
- After 3 retries: Mark as `.failed`, show error icon
- User can tap to retry manually
- Never silently drop messages

### Receiving while offline

**Messages pile up in Firestore:**
- Other users' messages written to Firestore as normal
- Your device is offline, so listeners are paused

**On reconnect:**
- Firestore automatically fetches missed messages
- Listener fires with all accumulated changes
- Batch insert to Core Data
- Update UI with smooth animation
- Show unread count badge

---

## Performance Targets

- **Message send latency:** <100ms (optimistic UI)
- **Message delivery:** <500ms (online recipients)
- **App cold start:** <2 seconds
- **Conversation list load:** <1 second (Core Data cached)
- **Chat history load:** <500ms (50 messages from Core Data)
- **Typing indicator:** <200ms (Firestore ephemeral)
- **AI feature response:** <3 seconds (Cloud Function + LLM)
- **Offline sync:** <5 seconds on reconnect (100 pending messages)
- **Push notification:** <10 seconds (APNs delivery)

---

## Security & Firestore Rules

### Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return request.auth.uid == userId;
    }
    
    function isParticipant(conversationId) {
      return request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participantIds;
    }
    
    // Users can read/write their own profile
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow write: if isOwner(userId);
    }
    
    // Conversations: participants only
    match /conversations/{conversationId} {
      allow read: if isAuthenticated() && isParticipant(conversationId);
      allow create: if isAuthenticated() && request.auth.uid in request.resource.data.participantIds;
      allow update: if isAuthenticated() && isParticipant(conversationId);
      
      // Messages within conversation
      match /messages/{messageId} {
        allow read: if isAuthenticated() && isParticipant(conversationId);
        allow create: if isAuthenticated() 
                      && isParticipant(conversationId)
                      && request.resource.data.senderId == request.auth.uid;
        allow update: if isAuthenticated() && isParticipant(conversationId);
      }
      
      // AI insights
      match /insights/{insightId} {
        allow read: if isAuthenticated() && isParticipant(conversationId);
        allow write: if false; // Only Cloud Functions can write
      }
      
      // Typing indicators
      match /typing/{userId} {
        allow read: if isAuthenticated() && isParticipant(conversationId);
        allow write: if isAuthenticated() && isOwner(userId);
      }
    }
  }
}
```

---

## iOS-Specific Implementation Details

### SwiftUI + Combine for Real-Time Updates

```swift
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var typingUsers: [String] = []
    @Published var isLoading = false
    
    private var messageListener: ListenerRegistration?
    private var typingListener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()
    
    func loadMessages(conversationId: String) {
        // Load from Core Data first (instant)
        messages = CoreDataService.shared.fetchMessages(conversationId: conversationId)
        
        // Then subscribe to Firestore for real-time updates
        messageListener = FirestoreService.shared.subscribeToMessages(conversationId: conversationId) { [weak self] newMessages in
            self?.messages = newMessages
            CoreDataService.shared.saveMessages(newMessages)
        }
    }
    
    func sendMessage(text: String, conversationId: String) {
        let localId = UUID().uuidString
        let message = Message(
            id: localId,
            conversationId: conversationId,
            senderId: AuthService.shared.currentUserId,
            senderName: AuthService.shared.currentUser?.displayName ?? "",
            senderPhotoURL: AuthService.shared.currentUser?.photoURL,
            type: .text,
            text: text,
            imageURL: nil,
            createdAt: Date(),
            status: .sending,
            deliveredTo: [],
            readBy: [],
            localId: localId,
            isSynced: false,
            priority: false
        )
        
        // Optimistic UI update
        messages.append(message)
        CoreDataService.shared.saveMessage(message)
        
        // Background upload
        Task {
            await FirestoreService.shared.sendMessage(message)
        }
    }
}
```

### Core Data Stack

```swift
class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init() {
        container = NSPersistentContainer(name: "MessageAI")
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    func save() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save Core Data: \(error)")
            }
        }
    }
}
```

### Network Monitoring with Network Framework

```swift
import Network

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    @Published var isConnected = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                if path.status == .satisfied {
                    SyncManager.shared.syncPendingMessages()
                }
            }
        }
        monitor.start(queue: queue)
    }
}
```

---

## Known Limitations & Trade-offs

1. **iOS only:** No Android support in MVP (single platform for 7-day sprint)
2. **Requires macOS:** Development needs Xcode on Mac
3. **No SwiftUI Previews for Firebase:** Must run on simulator/device for testing
4. **Basic media support:** Images only (no video/audio in MVP)
5. **Simple search:** Keyword-based initially (semantic search later)
6. **No end-to-end encryption:** Messages stored in plaintext
7. **No message editing:** Edit/delete out of scope for MVP
8. **Background notifications:** Requires APNs certificate setup
9. **AI rate limits:** Free tier has token limits (monitor usage)
10. **Offline time limit:** Long offline periods (days) may hit sync limits

---

## Success Metrics for MVP Checkpoint (24 Hours)

1. **Two users can chat in real-time** across different iPhones
2. **Messages appear instantly** with optimistic UI (<100ms)
3. **Offline scenario works:** Send while offline → receive on reconnect
4. **App lifecycle handling:** Background/foreground/force-quit preserves state
5. **Read receipts update** in real-time
6. **Group chat works** with 3+ participants
7. **Typing indicators show** within 200ms
8. **Push notifications fire** (at least in foreground)

---

## Risk Mitigation

**Biggest Risk:** Offline sync breaking with race conditions  
**Mitigation:** Use Core Data transactions; test offline scenarios early; comprehensive error handling

**Second Risk:** Push notifications not working on physical devices  
**Mitigation:** Test on real iOS hardware; don't rely on simulator; setup APNs certificates early

**Third Risk:** Firestore costs exploding with too many reads  
**Mitigation:** Use Core Data caching aggressively; limit Firestore queries; monitor usage

**Fourth Risk:** AI features taking too long to build  
**Mitigation:** Start with simplest (summarization); use basic prompts; optimize later

**Fifth Risk:** 24-hour MVP deadline too aggressive  
**Mitigation:** Focus ruthlessly on core messaging first; defer AI to post-MVP if needed

**Sixth Risk:** SwiftUI learning curve  
**Mitigation:** Use simple, declarative patterns; avoid complex animations initially; focus on functionality

---

## Development Environment Setup

### Prerequisites
- macOS Ventura 13.0+ with Xcode 15+
- iOS 16.0+ test device (physical device recommended for push notifications)
- Firebase account
- Anthropic API key
- Apple Developer account (for TestFlight and push notifications)

### Firebase Project Setup
1. Create Firebase project: "messageai-prod"
2. Add iOS app with bundle ID: `com.yourdomain.messageai`
3. Download `GoogleService-Info.plist`
4. Enable Authentication (Email/Password + Google)
5. Create Firestore database (test mode)
6. Enable Storage
7. Setup Cloud Messaging with APNs certificate

### Xcode Project Setup
1. Create new iOS App project (SwiftUI, iOS 16.0+)
2. Add `GoogleService-Info.plist` to project
3. Add Firebase SDK via Swift Package Manager
4. Configure Core Data model
5. Setup Info.plist permissions (camera, photos, notifications)
6. Configure signing & capabilities (Push Notifications, Background Modes)

---

## Document Version History

- v2.0 (2025-10-21): iOS Native Architecture - Swift/SwiftUI implementation