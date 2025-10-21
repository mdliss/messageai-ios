# MessageAI MVP - Development Task List (iOS Swift/SwiftUI) - REVISED

## Timeline Overview

- **MVP Checkpoint:** Tuesday 10:59 PM (24 hours) - Core messaging must work
- **Early Submission:** Friday 10:59 PM (4 days) - All AI features working
- **Final Submission:** Sunday 10:59 PM (7 days) - Polished, deployed, demo video

---

## PR #1: Project Setup & Firebase Configuration ✅ COMPLETE

**Branch:** `setup/initial-config`  
**Goal:** Initialize iOS Swift/SwiftUI project with Firebase configured  
**Complexity:** 3/10  
**Time Estimate:** 2-3 hours  
**Status:** ✅ Complete

---

## PR #2: User Model & Auth Service

**Branch:** `feature/auth-models`  
**Goal:** Create User model and AuthService foundation  
**Complexity:** 4/10  
**Time Estimate:** 1-2 hours

### Tasks:

- [ ] **2.1: Create User Model**
  - Files to create: `Models/User.swift`
  - Codable struct matching Firestore schema
  - Properties: id, email, displayName, photoURL, isOnline, lastSeen, fcmToken, createdAt, preferences
  - UserPreferences struct for settings

- [ ] **2.2: Create AuthService**
  - Files to create: `Services/AuthService.swift`
  - Singleton pattern with FirebaseConfig.shared
  - Functions:
    - `signUp(email:password:displayName:) async throws -> User`
    - `signIn(email:password:) async throws -> User`
    - `signInWithGoogle() async throws -> User`
    - `signOut() throws`
    - `createUserProfile(user:) async throws`
  - Current user state management
  - Firebase Auth listener

**PR Checklist:**

- [ ] User model compiles without errors
- [ ] AuthService singleton initializes
- [ ] All auth methods have proper error handling
- [ ] No Firebase errors in console

---

## PR #3: Authentication UI & ViewModel

**Branch:** `feature/auth-ui`  
**Goal:** Complete authentication screens with MVVM pattern  
**Complexity:** 6/10  
**Time Estimate:** 2-3 hours

### Tasks:

- [ ] **3.1: Create AuthViewModel**
  - Files to create: `ViewModels/AuthViewModel.swift`
  - ObservableObject with @Published properties
  - Properties: currentUser, isLoading, errorMessage, isAuthenticated
  - Listen to Firebase auth state changes
  - Methods: signUp, signIn, signInWithGoogle, signOut

- [ ] **3.2: Create LoginView**
  - Files to create: `Views/Auth/LoginView.swift`
  - SwiftUI form with email/password fields
  - "Sign In" button with loading state
  - "Sign in with Google" button
  - NavigationLink to RegisterView
  - Error alert display

- [ ] **3.3: Create RegisterView**
  - Files to create: `Views/Auth/RegisterView.swift`
  - Form fields: display name, email, password, confirm password
  - "Sign Up" button
  - Password validation (min 8 chars, match confirmation)
  - Error handling with alerts

- [ ] **3.4: Create ProfileView**
  - Files to create: `Views/Profile/ProfileView.swift`
  - Display: user name, email, photo
  - "Sign Out" button with confirmation dialog
  - Loading states

- [ ] **3.5: Create AuthContainerView**
  - Files to create: `Views/Auth/AuthContainerView.swift`
  - Show LoginView if not authenticated
  - Show TabView if authenticated
  - Loading state during auth check

- [ ] **3.6: Update App Entry Point**
  - Files to update: `messageAI/messageAIApp.swift`
  - Add AuthViewModel as @StateObject
  - Inject as environment object
  - Set ContentView to AuthContainerView

**PR Checklist:**

- [ ] Can create new account with email/password
- [ ] Can login with existing credentials
- [ ] Can logout successfully
- [ ] Auth state persists on app restart
- [ ] Google Sign-In works
- [ ] Error messages display correctly
- [ ] User profile created in Firestore on signup

---

## PR #4: Core Data Models & Persistence

**Branch:** `feature/core-data`  
**Goal:** Set up Core Data for offline message persistence  
**Complexity:** 6/10  
**Time Estimate:** 2-3 hours

### Tasks:

- [ ] **4.1: Create Core Data Model**
  - In Xcode: File → New → File → Data Model
  - Name: `MessageAI.xcdatamodeld`
  - Location: `CoreData/` folder

- [ ] **4.2: Define MessageEntity**
  - Entity: "MessageEntity"
  - Attributes: id (String), conversationId (String), senderId (String), senderName (String), senderPhotoURL (String, optional), type (String), text (String), imageURL (String, optional), createdAt (Date), status (String), deliveredTo (String), readBy (String), localId (String, optional), isSynced (Bool), priority (Bool)
  - Set "id" as unique constraint
  - Relationship: conversation → ConversationEntity

- [ ] **4.3: Define ConversationEntity**
  - Entity: "ConversationEntity"
  - Attributes: id (String), type (String), participantIds (String), participantDetailsJSON (String), lastMessageText (String, optional), lastMessageTimestamp (Date, optional), unreadCount (Int32), updatedAt (Date), groupName (String, optional)
  - Set "id" as unique constraint
  - Relationship: messages → MessageEntity (one-to-many)

- [ ] **4.4: Create PersistenceController**
  - Files to create: `CoreData/PersistenceController.swift`
  - Singleton pattern
  - Initialize NSPersistentContainer
  - Configure merge policies for conflicts
  - Provide save() method with error handling

- [ ] **4.5: Create CoreDataService**
  - Files to create: `Services/CoreDataService.swift`
  - Message operations: saveMessage, fetchMessages, updateMessage, deleteMessage, fetchUnsyncedMessages
  - Conversation operations: saveConversation, fetchConversations, updateConversation
  - Batch operations for efficiency

- [ ] **4.6: Create Core Data Extensions**
  - Files to create: `CoreData/CoreDataExtensions.swift`
  - Extension on MessageEntity: toMessage() conversion
  - Extension on ConversationEntity: toConversation() conversion
  - NSFetchRequest helpers

**PR Checklist:**

- [ ] Core Data model created
- [ ] PersistenceController initializes successfully
- [ ] Can save messages to Core Data
- [ ] Can query messages (sorted by date)
- [ ] Can update message status
- [ ] Data persists across app restarts
- [ ] No Core Data errors in console

---

## PR #5: Conversation & Message Models

**Branch:** `feature/data-models`  
**Goal:** Create all data models for messaging  
**Complexity:** 4/10  
**Time Estimate:** 1-2 hours

### Tasks:

- [ ] **5.1: Create Conversation Model**
  - Files to create: `Models/Conversation.swift`
  - Codable struct matching Firestore schema
  - Enums: ConversationType (direct, group)
  - Structs: ParticipantDetail, LastMessage

- [ ] **5.2: Create Message Model**
  - Files to create: `Models/Message.swift`
  - Codable struct matching Firestore schema
  - Enums: MessageType (text, image), MessageStatus (sending, sent, delivered, read, failed)

- [ ] **5.3: Create AIInsight Model**
  - Files to create: `Models/AIInsight.swift`
  - Codable struct for AI features
  - Enums: InsightType (summary, actionItems, decision, priority, suggestion)
  - Struct: InsightMetadata

- [ ] **5.4: Create TypingIndicator Model**
  - Files to create: `Models/TypingIndicator.swift`
  - Simple struct for typing state

**PR Checklist:**

- [ ] All models compile without errors
- [ ] Codable conformance works
- [ ] Enums have proper raw values
- [ ] Models match Firestore schema exactly

---

## PR #6: Firestore Service Foundation

**Branch:** `feature/firestore-service`  
**Goal:** Create FirestoreService for all database operations  
**Complexity:** 7/10  
**Time Estimate:** 3-4 hours

### Tasks:

- [ ] **6.1: Create FirestoreService**
  - Files to create: `Services/FirestoreService.swift`
  - Singleton pattern with FirebaseConfig.shared.db
  - User operations:
    - `createUserProfile(_:) async throws`
    - `getUser(_:) async throws -> User`
    - `updateUserOnlineStatus(_:isOnline:) async throws`

- [ ] **6.2: Add Conversation Operations**
  - Functions:
    - `getUserConversations(userId:) -> AsyncStream<[Conversation]>`
    - `createConversation(participantIds:type:) async throws -> Conversation`
    - `createGroupConversation(participantIds:groupName:) async throws -> Conversation`
    - `getConversation(_:) async throws -> Conversation`

- [ ] **6.3: Add Message Operations**
  - Functions:
    - `subscribeToMessages(conversationId:) -> AsyncStream<[Message]>`
    - `sendMessage(_:to:) async throws -> String`
    - `updateMessageStatus(messageId:conversationId:status:) async throws`
    - `markMessagesAsRead(conversationId:messageIds:userId:) async throws`

**PR Checklist:**

- [ ] FirestoreService initializes correctly
- [ ] All async functions have proper error handling
- [ ] AsyncStream listeners work for real-time updates
- [ ] Can create and fetch users
- [ ] Can create and fetch conversations
- [ ] Can send and receive messages
- [ ] No Firestore errors in console

---

## PR #7: Conversation List Screen

**Branch:** `feature/conversation-list`  
**Goal:** Display list of conversations  
**Complexity:** 6/10  
**Time Estimate:** 2-3 hours

### Tasks:

- [ ] **7.1: Create ConversationViewModel**
  - Files to create: `ViewModels/ConversationViewModel.swift`
  - ObservableObject with @Published conversations array
  - Subscribe to Firestore conversations
  - Sync to Core Data in background
  - Method: createConversation, createGroupConversation
  - Handle loading and error states

- [ ] **7.2: Create ConversationRowView**
  - Files to create: `Views/Conversations/ConversationRowView.swift`
  - Display: avatar (circle), name, last message preview, timestamp
  - Show unread count badge if > 0
  - Show online status indicator (green/gray dot)
  - Relative timestamps ("5m ago", "Yesterday")

- [ ] **7.3: Create ConversationListView**
  - Files to create: `Views/Conversations/ConversationListView.swift`
  - NavigationStack with list of ConversationRowView
  - Pull-to-refresh
  - Empty state: "No conversations yet"
  - Toolbar button: "New Message" (sheet for user picker)
  - NavigationDestination for ChatView

- [ ] **7.4: Create UserPickerView**
  - Files to create: `Views/Conversations/UserPickerView.swift`
  - List all users from Firestore
  - Filter out current user
  - Search bar
  - Tap user → create conversation → dismiss sheet

**PR Checklist:**

- [ ] Conversation list displays correctly
- [ ] Last message preview shows
- [ ] Unread count badge appears
- [ ] Can tap conversation (navigates to placeholder)
- [ ] Can open user picker
- [ ] Can create new conversation
- [ ] Empty state shows when no conversations
- [ ] Pull to refresh works

---

## PR #8A: Basic Chat View (UI Only)

**Branch:** `feature/chat-view-basic`  
**Goal:** Create chat UI components without real-time functionality  
**Complexity:** 5/10  
**Time Estimate:** 2-3 hours

### Tasks:

- [ ] **8A.1: Create MessageBubbleView**
  - Files to create: `Views/Chat/MessageBubbleView.swift`
  - Display message text in bubble
  - Different styles: own messages (right, blue) vs others (left, gray)
  - Show sender name for group chats
  - Show timestamp (relative)
  - Status indicators: clock (sending), checkmark (sent), double checkmark (delivered), blue checkmark (read)
  - Support text and image types

- [ ] **8A.2: Create MessageInputView**
  - Files to create: `Views/Chat/MessageInputView.swift`
  - TextField for message input
  - Send button (SF Symbol: arrow.up.circle.fill)
  - Disable send if text is empty
  - Camera/photo button
  - Proper keyboard handling

- [ ] **8A.3: Create ChatView (Static)**
  - Files to create: `Views/Chat/ChatView.swift`
  - ScrollView with LazyVStack of MessageBubbleView
  - MessageInputView at bottom
  - Navigation title with conversation name
  - Mock data for testing UI
  - ScrollViewReader for scroll control

- [ ] **8A.4: Update Navigation**
  - Files to update: `Views/Conversations/ConversationListView.swift`
  - Add .navigationDestination for ChatView
  - Pass conversation ID

**PR Checklist:**

- [ ] Message bubbles render correctly
- [ ] Own vs other messages styled differently
- [ ] Timestamps show correctly
- [ ] Input field works
- [ ] Send button enables/disables properly
- [ ] Can navigate from conversation list to chat
- [ ] Keyboard behavior is correct

---

## PR #8B: Real-Time Chat & Optimistic UI

**Branch:** `feature/chat-realtime`  
**Goal:** Add real-time messaging with optimistic updates  
**Complexity:** 6/10  
**Time Estimate:** 2-3 hours

### Tasks:

- [ ] **8B.1: Create ChatViewModel**
  - Files to create: `ViewModels/ChatViewModel.swift`
  - ObservableObject with @Published messages array
  - Subscribe to Firestore messages (real-time)
  - Load from Core Data first (fast initial load)
  - Sync real-time updates to Core Data
  - Method: sendMessage with optimistic UI
  - Method: sendImageMessage
  - Handle loading and error states

- [ ] **8B.2: Update ChatView for Real-Time**
  - Files to update: `Views/Chat/ChatView.swift`
  - Remove mock data
  - Add @StateObject ChatViewModel
  - Load messages on appear
  - Send message handler
  - Auto-scroll to bottom on new messages
  - Pull to load more (pagination)

- [ ] **8B.3: Implement Optimistic UI**
  - When user sends message:
    - Generate local UUID
    - Create message with status = .sending
    - Append to messages array immediately
    - Save to Core Data with isSynced = false
    - Upload to Firestore in background
    - Update with server ID on success

**PR Checklist:**

- [ ] Can send text messages
- [ ] Messages appear instantly (optimistic UI)
- [ ] Messages from other user appear in real-time
- [ ] Message status updates (sending → sent)
- [ ] Chat scrolls to bottom on new message
- [ ] Messages load from Core Data on open
- [ ] Can navigate between conversations
- [ ] Real-time listener works correctly

---

## PR #9A: Network Monitoring

**Branch:** `feature/network-monitor`  
**Goal:** Track network connectivity for offline support  
**Complexity:** 4/10  
**Time Estimate:** 1-2 hours

### Tasks:

- [ ] **9A.1: Create NetworkMonitor**
  - Files to create: `Utilities/NetworkMonitor.swift`
  - Use NWPathMonitor to track network status
  - ObservableObject with @Published isConnected
  - Singleton pattern
  - Post notification on reconnect

- [ ] **9A.2: Create NetworkBanner**
  - Files to create: `Views/Components/NetworkBanner.swift`
  - Banner at top: "You're offline. Messages will send when connected."
  - Auto-hide when back online
  - Smooth slide animation

- [ ] **9A.3: Integrate into App**
  - Files to update: `messageAI/messageAIApp.swift`
  - Initialize NetworkMonitor.shared
  - Files to update: `Views/Chat/ChatView.swift`
  - Add NetworkBanner conditionally

**PR Checklist:**

- [ ] NetworkMonitor detects connection changes
- [ ] Banner shows when offline
- [ ] Banner hides when online
- [ ] Network state updates in real-time

---

## PR #9B: Sync Queue & Offline Messaging

**Branch:** `feature/offline-sync`  
**Goal:** Queue messages offline and sync on reconnect  
**Complexity:** 6/10  
**Time Estimate:** 2-3 hours

### Tasks:

- [ ] **9B.1: Create SyncService**
  - Files to create: `Services/SyncService.swift`
  - ObservableObject with @Published isSyncing, pendingCount
  - Method: processPendingMessages()
  - Query Core Data for isSynced = false
  - Upload each to Firestore
  - Update Core Data with server ID on success
  - Retry logic: max 3 attempts with exponential backoff
  - Handle failures gracefully

- [ ] **9B.2: Update ChatViewModel for Offline**
  - Files to update: `ViewModels/ChatViewModel.swift`
  - Save message to Core Data with isSynced = false when offline
  - Show "sending" status
  - Listen to NetworkMonitor for reconnection
  - Trigger SyncService on reconnect

- [ ] **9B.3: Handle Offline Image Uploads**
  - Store image locally in Documents directory
  - Queue for upload when reconnected
  - Show "waiting to upload" status
  - Delete local copy after successful upload

- [ ] **9B.4: Integrate Sync Service**
  - Files to update: `messageAI/messageAIApp.swift`
  - Initialize SyncService
  - Listen for reconnection notifications
  - Trigger processPendingMessages()

**PR Checklist:**

- [ ] Can send messages while offline
- [ ] Messages queue in Core Data with isSynced = false
- [ ] Messages auto-upload on reconnect
- [ ] Can view past messages while offline
- [ ] Failed messages show error icon
- [ ] Retry logic works (max 3 attempts)
- [ ] No message loss

---

## PR #10: Read Receipts & Typing Indicators

**Branch:** `feature/receipts-typing`  
**Goal:** Show read receipts and typing indicators  
**Complexity:** 6/10  
**Time Estimate:** 2-3 hours

### Tasks:

- [ ] **10.1: Implement Read Receipts**
  - Files to update: `Services/FirestoreService.swift`
  - Add function: `markMessagesAsRead(conversationId:messageIds:userId:) async throws`
  - Batch update readBy array in Firestore
  - Files to update: `ViewModels/ChatViewModel.swift`
  - On ChatView appear: mark visible messages as read
  - Update message status based on readBy array

- [ ] **10.2: Update MessageBubbleView with Read Status**
  - Files to update: `Views/Chat/MessageBubbleView.swift`
  - For own messages, show status icons:
    - Clock: status = .sending
    - Single checkmark: status = .sent
    - Double checkmark: status = .delivered
    - Blue double checkmark: status = .read
  - For group chats: show "Read by 3 of 5"

- [ ] **10.3: Create RealtimeDBService for Typing**
  - Files to create: `Services/RealtimeDBService.swift`
  - Use Firebase Realtime Database
  - Functions:
    - `setTyping(conversationId:userId:isTyping:) async`
    - `observeTyping(conversationId:) -> AsyncStream<[String]>`
  - Path: typing/{conversationId}/{userId}
  - Auto-delete after 10 seconds

- [ ] **10.4: Add Typing Detection to ChatViewModel**
  - Files to update: `ViewModels/ChatViewModel.swift`
  - @Published var typingUsers: [String]
  - Subscribe to typing status
  - Debounce text input changes (500ms)
  - Update typing status: true when typing, false after 3s inactivity

- [ ] **10.5: Create TypingIndicatorView**
  - Files to create: `Views/Chat/TypingIndicatorView.swift`
  - Display: "Alice is typing..." (1 user)
  - Display: "Alice, Bob are typing..." (2+ users)
  - Animated dots (...)

- [ ] **10.6: Integrate Typing into ChatView**
  - Files to update: `Views/Chat/ChatView.swift`
  - Add TypingIndicatorView above input
  - Update typing status on text change
  - Pass viewModel.typingUsers

**PR Checklist:**

- [ ] Read receipts update in real-time
- [ ] Checkmarks change color (gray → blue)
- [ ] Typing indicator appears within 200ms
- [ ] Typing indicator disappears after 3s inactivity
- [ ] Works with multiple users typing
- [ ] Typing stored in Realtime Database

---

## PR #11: Presence & Online Status

**Branch:** `feature/presence`  
**Goal:** Show who's online/offline  
**Complexity:** 5/10  
**Time Estimate:** 1-2 hours

### Tasks:

- [ ] **11.1: Add Presence to RealtimeDBService**
  - Files to update: `Services/RealtimeDBService.swift`
  - Functions:
    - `setUserOnline(userId:) async`
    - `setUserOffline(userId:) async`
    - `observePresence(userId:) -> AsyncStream<Bool>`
  - Path: presence/{userId}
  - Use onDisconnect() to auto-set offline

- [ ] **11.2: Integrate Presence into AuthViewModel**
  - Files to update: `ViewModels/AuthViewModel.swift`
  - On login: call setUserOnline()
  - On logout: call setUserOffline()
  - Listen to app lifecycle (scenePhase):
    - Active → setUserOnline()
    - Background/Inactive → setUserOffline()

- [ ] **11.3: Display Presence in ConversationRowView**
  - Files to update: `Views/Conversations/ConversationRowView.swift`
  - Show green dot for online users
  - Show gray dot with "last seen X ago" for offline
  - Subscribe to presence for participants

- [ ] **11.4: Display Presence in ChatView**
  - Files to update: `Views/Chat/ChatView.swift`
  - Show presence in navigation bar subtitle
  - "Online" or "Last seen X ago"
  - Subscribe to presence for conversation participants

**PR Checklist:**

- [ ] Online status shows green dot
- [ ] Offline shows gray dot with "last seen"
- [ ] Presence updates within 5 seconds
- [ ] Auto-sets offline when app closes
- [ ] Presence stored in Realtime Database

---

## PR #12: Group Chat Support

**Branch:** `feature/group-chat`  
**Goal:** Support conversations with 3+ participants  
**Complexity:** 7/10  
**Time Estimate:** 3-4 hours

### Tasks:

- [ ] **12.1: Update MessageBubbleView for Groups**
  - Files to update: `Views/Chat/MessageBubbleView.swift`
  - Show sender name for ALL messages in group chats
  - Show sender avatar if available
  - Different layout for group messages

- [ ] **12.2: Update Read Receipts for Groups**
  - Files to update: `Views/Chat/MessageBubbleView.swift`
  - Show count: "Read by 3 of 5"
  - Optional: Tap to see who read (sheet with list)

- [ ] **12.3: Update TypingIndicatorView for Groups**
  - Files to update: `Views/Chat/TypingIndicatorView.swift`
  - Handle multiple users: "Alice, Bob, and 2 others are typing..."

- [ ] **12.4: Create GroupCreationView**
  - Files to create: `Views/Conversations/GroupCreationView.swift`
  - Multi-select user picker (checkboxes)
  - Group name input field
  - "Create Group" button
  - Requires 2+ selected users
  - Validation and error handling

- [ ] **12.5: Update ConversationRowView for Groups**
  - Files to update: `Views/Conversations/ConversationRowView.swift`
  - Display group name OR auto-generate: "Alice, Bob, +2"
  - Show group icon/avatar placeholder
  - Handle multiple participants for presence

- [ ] **12.6: Add Group Creation Navigation**
  - Files to update: `Views/Conversations/ConversationListView.swift`
  - Add toolbar menu with "New Message" and "New Group"
  - Present GroupCreationView as sheet
  - Pass conversation list view model

**PR Checklist:**

- [ ] Can create group with 3+ users
- [ ] All participants receive messages in real-time
- [ ] Sender name shows for each message
- [ ] Read receipts show count
- [ ] Typing indicators work for multiple users
- [ ] Group name displays correctly

---

## PR #13: Image Sharing

**Branch:** `feature/images`  
**Goal:** Send and receive images  
**Complexity:** 7/10  
**Time Estimate:** 3-4 hours

### Tasks:

- [ ] **13.1: Create StorageService**
  - Files to create: `Services/StorageService.swift`
  - Singleton pattern with FirebaseConfig.shared.storage
  - Function: `uploadImage(_:path:) async throws -> String` (returns URL)
  - Function: `deleteImage(path:) async throws`
  - Path: `images/{conversationId}/{timestamp}_{UUID}.jpg`
  - Compress images before upload (JPEG quality 0.8)

- [ ] **13.2: Create ImagePicker**
  - Files to create: `Views/Chat/ImagePicker.swift`
  - Use PhotosUI PhotosPicker for gallery
  - Use UIImagePickerController wrapper for camera
  - Return UIImage
  - Handle permissions

- [ ] **13.3: Create Image Utilities**
  - Files to create: `Utilities/ImageCompressor.swift`
  - Function: compress image to max size
  - Function: resize image maintaining aspect ratio
  - JPEG compression with quality parameter

- [ ] **13.4: Add Image Selection to ChatView**
  - Files to update: `Views/Chat/ChatView.swift`
  - Add camera/photo button in input area
  - Show ImagePicker sheet
  - On image selected: show preview, send on confirm

- [ ] **13.5: Update ChatViewModel for Images**
  - Files to update: `ViewModels/ChatViewModel.swift`
  - Method: `sendImageMessage(image:conversationId:senderId:senderName:) async`
  - Compress image
  - Upload to Storage
  - Get download URL
  - Send message with type = .image, imageURL = downloadURL
  - Show upload progress

- [ ] **13.6: Update MessageBubbleView for Images**
  - Files to update: `Views/Chat/MessageBubbleView.swift`
  - If type == .image: render AsyncImage
  - Show loading placeholder during upload
  - Tap to view full-screen
  - Create full-screen image viewer (sheet)

- [ ] **13.7: Handle Offline Image Uploads**
  - Save image to Documents directory
  - Save message with local image path
  - Queue for upload on reconnect
  - Show "waiting to upload" status

**PR Checklist:**

- [ ] Can select image from library
- [ ] Can capture photo with camera
- [ ] Image uploads to Storage
- [ ] Image displays in chat
- [ ] Upload progress shows
- [ ] Tap image to view full-screen
- [ ] Offline images queue correctly

---

## PR #14: Push Notifications

**Branch:** `feature/push-notifications`  
**Goal:** Receive notifications for new messages  
**Complexity:** 7/10  
**Time Estimate:** 3-4 hours

### Tasks:

- [ ] **14.1: Create NotificationService**
  - Files to create: `Services/NotificationService.swift`
  - Request notification permissions
  - Get FCM token
  - Store token in Firestore `/users/{userId}/fcmToken`
  - Handle notification tap (deep linking)
  - Handle foreground notifications

- [ ] **14.2: Configure APNs in Firebase**
  - Upload APNs authentication key or certificate
  - Configure for development and production

- [ ] **14.3: Add Push Capabilities**
  - In Xcode: Target → Signing & Capabilities
  - Add "Push Notifications"
  - Add "Background Modes" → check "Remote notifications"

- [ ] **14.4: Integrate NotificationService**
  - Files to update: `messageAI/messageAIApp.swift`
  - Request permissions on launch
  - Get and store FCM token
  - Listen to notification taps
  - Set up notification handlers

- [ ] **14.5: Create Cloud Function for Notifications**
  - Create: `functions/src/notifications/sendMessage.ts`
  - Trigger: onCreate for messages
  - Get recipient FCM tokens (exclude sender)
  - Send notification via FCM with data payload

- [ ] **14.6: Handle Notification Navigation**
  - Files to update: `Services/NotificationService.swift`
  - Parse conversationId from data
  - Navigate to ChatView for conversation
  - Handle deep linking state

**PR Checklist:**

- [ ] Foreground notifications show banner
- [ ] Background notifications appear in system tray
- [ ] Tapping notification opens conversation
- [ ] FCM token saved to Firestore
- [ ] Cloud Function deployed
- [ ] Works on physical device

---

## PR #15: AI Feature Setup & Summarization

**Branch:** `feature/ai-summarization`  
**Goal:** Set up AI infrastructure and implement thread summarization  
**Complexity:** 6/10  
**Time Estimate:** 3-4 hours

### Tasks:

- [ ] **15.1: Set Up Cloud Functions for AI**
  - Navigate to functions/ directory
  - Install: `npm install @anthropic-ai/sdk`
  - Store API key: `firebase functions:config:set anthropic.key="sk-..."`
  - Create: `functions/src/ai/summarize.ts`

- [ ] **15.2: Create Summarization Cloud Function**
  - HTTPS callable function: `summarizeConversation`
  - Parameters: conversationId
  - Retrieve last 100 messages
  - Format as transcript
  - Call Claude API
  - Store result in insights subcollection
  - Return summary

- [ ] **15.3: Create AIInsightsViewModel**
  - Files to create: `ViewModels/AIInsightsViewModel.swift`
  - ObservableObject
  - Method: `summarize(conversationId:) async throws -> AIInsight`
  - Call Cloud Function via Firebase Functions
  - Subscribe to insights subcollection
  - Handle loading and errors

- [ ] **15.4: Create AIInsightCardView**
  - Files to create: `Views/AI/AIInsightCardView.swift`
  - Display: icon, title, content, timestamp
  - Dismissible with X button
  - Different styles for insight types
  - Smooth animations

- [ ] **15.5: Add Summarize to ChatView**
  - Files to update: `Views/Chat/ChatView.swift`
  - Add toolbar button: "Summarize"
  - On tap: show loading, call summarize()
  - Display AIInsightCardView with result
  - Handle errors with alerts

- [ ] **15.6: Deploy Cloud Function**
  - `firebase deploy --only functions:summarizeConversation`
  - Test in app with long conversation

**PR Checklist:**

- [ ] "Summarize" button appears
- [ ] Generates summary within 3 seconds
- [ ] Summary displays as card
- [ ] Summary is accurate (3 bullet points)
- [ ] Works with 50+ messages
- [ ] AI Insight persists

---

## PR #16: AI Action Item Extraction

**Branch:** `feature/ai-action-items`  
**Goal:** Extract tasks with owners from conversation  
**Complexity:** 5/10  
**Time Estimate:** 2-3 hours

### Tasks:

- [ ] **16.1: Create Action Items Cloud Function**
  - Create: `functions/src/ai/actionItems.ts`
  - HTTPS callable: `extractActionItems`
  - Retrieve messages (same as summarization)
  - Call Claude with action items prompt
  - Store as AI Insight with type = 'action_items'

- [ ] **16.2: Add to AIInsightsViewModel**
  - Files to update: `ViewModels/AIInsightsViewModel.swift`
  - Method: `extractActionItems(conversationId:) async throws -> AIInsight`

- [ ] **16.3: Add Action Items Button**
  - Files to update: `Views/Chat/ChatView.swift`
  - Add toolbar button: "Action Items"
  - Same pattern as summarization

- [ ] **16.4: Update AIInsightCardView**
  - Files to update: `Views/AI/AIInsightCardView.swift`
  - Render action items as bulleted list
  - Highlight owners (bold text)

- [ ] **16.5: Deploy Function**
  - `firebase deploy --only functions:extractActionItems`

**PR Checklist:**

- [ ] "Action Items" button works
- [ ] Extracts tasks with owners
- [ ] Captures deadlines when mentioned
- [ ] Displays as formatted list
- [ ] Generates within 3 seconds

---

## PR #17: AI Priority Message Detection

**Branch:** `feature/ai-priority`  
**Goal:** Automatically flag urgent messages  
**Complexity:** 6/10  
**Time Estimate:** 2-3 hours

### Tasks:

- [ ] **17.1: Create Priority Detection Function**
  - Create: `functions/src/ai/priority.ts`
  - Trigger: onCreate for messages
  - Pattern match: 'urgent', 'ASAP', 'critical', 'emergency'
  - If match: update message.priority = true
  - If ambiguous: call Claude to rate urgency
  - Update message doc

- [ ] **17.2: Update MessageBubbleView**
  - Files to update: `Views/Chat/MessageBubbleView.swift`
  - If priority == true: add red flag icon
  - Add red border around bubble
  - Different styling for urgent messages

- [ ] **17.3: Update Notification Function**
  - Files to update: `functions/src/notifications/sendMessage.ts`
  - Check if message.priority == true
  - Send high-priority notification
  - Use critical alert sound

- [ ] **17.4: Deploy Function**
  - `firebase deploy --only functions:detectPriority`

**PR Checklist:**

- [ ] Urgent messages auto-flagged
- [ ] Priority indicator shows (red flag)
- [ ] Sends push even if muted
- [ ] Low false positive rate
- [ ] Doesn't slow delivery

---

## PR #18: AI Smart Search

**Branch:** `feature/ai-search`  
**Goal:** Search messages with natural language  
**Complexity:** 5/10  
**Time Estimate:** 2-3 hours

### Tasks:

- [ ] **18.1: Create SearchViewModel**
  - Files to create: `ViewModels/SearchViewModel.swift`
  - ObservableObject
  - Method: `search(query:) async`
  - Query Core Data: `text CONTAINS[cd] query`
  - Return sorted results
  - Group by conversation

- [ ] **18.2: Create SearchView**
  - Files to create: `Views/Search/SearchView.swift`
  - Search bar at top
  - Results list below
  - Empty state
  - Grouped by conversation

- [ ] **18.3: Create SearchResultView**
  - Files to create: `Views/Search/SearchResultView.swift`
  - Display: preview, sender, conversation, timestamp
  - Highlight query in text
  - Tap to navigate to message

- [ ] **18.4: Add Search Navigation**
  - Files to update: `Views/Conversations/ConversationListView.swift`
  - Add toolbar search icon
  - Navigate to SearchView

**PR Checklist:**

- [ ] Search input works
- [ ] Returns results within 1 second
- [ ] Results accurate for keywords
- [ ] Can navigate to message
- [ ] Search across all conversations
- [ ] Query highlighted in results

---

## PR #19: AI Decision Tracking

**Branch:** `feature/ai-decisions`  
**Goal:** Log team decisions automatically  
**Complexity:** 6/10  
**Time Estimate:** 2-3 hours

### Tasks:

- [ ] **19.1: Create Decision Detection Function**
  - Create: `functions/src/ai/decisions.ts`
  - Trigger: onCreate for messages
  - Pattern match: "let's go with", "decided", "approved"
  - If match: call Claude to extract decision
  - Create AI Insight with type = 'decision'

- [ ] **19.2: Create DecisionsViewModel**
  - Files to create: `ViewModels/DecisionsViewModel.swift`
  - Subscribe to all decision insights
  - Filter and sort by date
  - Search functionality

- [ ] **19.3: Create DecisionsView**
  - Files to create: `Views/Decisions/DecisionsView.swift`
  - List all decisions
  - Group by date
  - Search bar
  - Tap to view in conversation

- [ ] **19.4: Add Decisions Tab**
  - Files to update: `Views/Auth/AuthContainerView.swift`
  - Add DecisionsView to TabView
  - Icon: "list.clipboard"

- [ ] **19.5: Deploy Function**
  - `firebase deploy --only functions:detectDecision`

**PR Checklist:**

- [ ] Decisions auto-logged
- [ ] Decisions screen shows all
- [ ] Decisions searchable
- [ ] Low false positives
- [ ] Can navigate to conversation

---

## PR #20A: Proactive Scheduling Detection

**Branch:** `feature/proactive-scheduling`  
**Goal:** Detect scheduling needs and offer help  
**Complexity:** 5/10  
**Time Estimate:** 2-3 hours

### Tasks:

- [ ] **20A.1: Create Proactive Detection Function**
  - Create: `functions/src/ai/proactive.ts`
  - Trigger: onCreate for messages
  - Pattern match: "when can", "schedule", "meeting"
  - If match: call Claude for confidence
  - If > 80%: create suggestion insight

- [ ] **20A.2: Display Suggestions in ChatView**
  - Files to update: `Views/Chat/ChatView.swift`
  - Listen for suggestion insights
  - Display AIInsightCardView with "Yes" and "Dismiss"
  - Handle user response

- [ ] **20A.3: Implement Scheduling Assistant**
  - On "Yes" tap:
    - Extract time mentions
    - Suggest 2-3 time slots
    - Post as AI assistant message

- [ ] **20A.4: Deploy Function**
  - `firebase deploy --only functions:detectProactiveSuggestions`

**PR Checklist:**

- [ ] Detects scheduling language (80%+)
- [ ] Suggestion appears as card
- [ ] "Yes" triggers assistant
- [ ] Low false positives

---

## PR #20B: AI Assistant Interface

**Branch:** `feature/ai-assistant`  
**Goal:** Dedicated AI assistant chat interface  
**Complexity:** 5/10  
**Time Estimate:** 2-3 hours

### Tasks:

- [ ] **20B.1: Create AIAssistantViewModel**
  - Files to create: `ViewModels/AIAssistantViewModel.swift`
  - ObservableObject
  - Chat with Claude about conversations
  - Show all insights
  - Answer questions

- [ ] **20B.2: Create AIAssistantView**
  - Files to create: `Views/AI/AIAssistantView.swift`
  - Chat interface
  - Can ask questions
  - Show all insights
  - Help with scheduling

- [ ] **20B.3: Add AI Tab**
  - Files to update: `Views/Auth/AuthContainerView.swift`
  - Add AIAssistantView to TabView
  - Icon: "sparkles"

**PR Checklist:**

- [ ] AI Assistant tab works
- [ ] Can chat with assistant
- [ ] Shows insights
- [ ] Helpful responses

---

## PR #21A: Multi-User & Offline Testing

**Branch:** `test/multi-user-offline`  
**Goal:** Comprehensive testing of core features  
**Complexity:** 4/10  
**Time Estimate:** 2-3 hours

### Tasks:

- [ ] **21A.1: Multi-User Testing**
  - Test with 3-5 concurrent users
  - All sending simultaneously
  - Check for race conditions
  - Verify no message loss/duplication

- [ ] **21A.2: Offline Scenario Testing**
  - User A offline, B sends 10 messages
  - A comes online → verify all received
  - A sends 5 offline → verify all send
  - Test image uploads offline

- [ ] **21A.3: App Lifecycle Testing**
  - Send message, force-quit, reopen
  - Background app, receive message
  - Switch conversations rapidly

- [ ] **21A.4: Document Bugs**
  - Create bug list
  - Prioritize by severity
  - Fix critical bugs

**PR Checklist:**

- [ ] Multi-user test passed
- [ ] Offline scenarios work
- [ ] Lifecycle handling correct
- [ ] Bugs documented

---

## PR #21B: AI Features Testing & Error Handling

**Branch:** `test/ai-features`  
**Goal:** Test all AI features with edge cases  
**Complexity:** 3/10  
**Time Estimate:** 1-2 hours

### Tasks:

- [ ] **21B.1: Test Each AI Feature**
  - Summarization: empty convo, 500+ messages
  - Action items: no tasks conversation
  - Priority: non-urgent messages
  - Search: no results, special characters
  - Decisions: ambiguous language
  - Proactive: non-scheduling convos

- [ ] **21B.2: Add Error Handling**
  - Files to update: All ViewModels
  - Try/catch on all async functions
  - User-friendly error messages
  - Handle API failures gracefully

- [ ] **21B.3: Handle Network Errors**
  - Firestore timeout errors
  - Storage upload failures
  - Cloud Function errors

**PR Checklist:**

- [ ] All AI features tested
- [ ] Error handling comprehensive
- [ ] Error messages helpful
- [ ] No crashes on errors

---

## PR #21C: UI Polish & Performance

**Branch:** `polish/ui-performance`  
**Goal:** Polish UI and optimize performance  
**Complexity:** 4/10  
**Time Estimate:** 2-3 hours

### Tasks:

- [ ] **21C.1: UI Consistency**
  - Consistent spacing (padding, margins)
  - Consistent colors (theme)
  - Consistent fonts and sizes
  - Smooth animations

- [ ] **21C.2: Loading & Empty States**
  - Add loading states to all views
  - Empty states for all lists
  - Skeleton screens where appropriate
  - Progress indicators

- [ ] **21C.3: Dark Mode Support**
  - Test all views in dark mode
  - Adjust colors for dark mode
  - Use Color.adaptive patterns

- [ ] **21C.4: Performance Optimization**
  - Minimize Firestore reads
  - Debounce typing indicators
  - Optimize image compression
  - Lazy load conversation list

- [ ] **21C.5: Accessibility**
  - Add accessibility labels
  - Test with VoiceOver
  - Color contrast checks
  - Dynamic Type support

**PR Checklist:**

- [ ] UI feels polished
- [ ] Loading states everywhere
- [ ] Dark mode works
- [ ] Performance smooth
- [ ] Accessible with VoiceOver

---

## PR #22: Firestore Security Rules

**Branch:** `deploy/security-rules`  
**Goal:** Set up production security rules  
**Complexity:** 4/10  
**Time Estimate:** 1-2 hours

### Tasks:

- [ ] **22.1: Create Firestore Rules**
  - Files to create: `firestore.rules`
  - Copy rules from architecture.md
  - Users: read all, write own
  - Conversations: participants only
  - Messages: participants only
  - Insights: read only (Cloud Functions write)

- [ ] **22.2: Create Realtime DB Rules**
  - Files to create: `database.rules.json`
  - Typing: participants only
  - Presence: all read, own write

- [ ] **22.3: Deploy Rules**
  - `firebase deploy --only firestore:rules`
  - `firebase deploy --only database`

- [ ] **22.4: Test Rules**
  - Test with unauthenticated user (should fail)
  - Test with wrong user (should fail)
  - Test with correct user (should succeed)

**PR Checklist:**

- [ ] Firestore rules deployed
- [ ] Realtime DB rules deployed
- [ ] Rules tested and working
- [ ] Unauthorized access blocked

---

## PR #23: Cloud Functions Deployment

**Branch:** `deploy/cloud-functions`  
**Goal:** Deploy all Cloud Functions to production  
**Complexity:** 5/10  
**Time Estimate:** 2-3 hours

### Tasks:

- [ ] **23.1: Finalize All Functions**
  - Review all function code
  - Add error handling
  - Add logging
  - Optimize for performance

- [ ] **23.2: Configure Environment**
  - Set Anthropic API key
  - Set other config values
  - Review Firebase config

- [ ] **23.3: Deploy All Functions**
  - `firebase deploy --only functions`
  - Verify all deployed successfully
  - Check logs for errors

- [ ] **23.4: Test Each Function**
  - sendMessageNotification
  - detectPriority
  - detectDecision
  - detectProactiveSuggestions
  - summarizeConversation
  - extractActionItems

**PR Checklist:**

- [ ] All functions deployed
- [ ] All functions tested
- [ ] Logs show no errors
- [ ] Performance acceptable

---

## PR #24: TestFlight Preparation

**Branch:** `deploy/testflight-prep`  
**Goal:** Prepare app for TestFlight submission  
**Complexity:** 6/10  
**Time Estimate:** 2-3 hours

### Tasks:

- [ ] **24.1: Configure App for Production**
  - Update Bundle ID if needed
  - Set version: 1.0.0
  - Set build number: 1
  - Configure signing (Apple Developer)

- [ ] **24.2: Add App Icons**
  - Create app icons (all sizes)
  - Add to Assets.xcassets
  - Set launch screen

- [ ] **24.3: Configure Capabilities**
  - Push Notifications enabled
  - Background Modes enabled
  - Sign In with Apple (if using)

- [ ] **24.4: Create Archive**
  - Product → Archive in Xcode
  - Wait for completion
  - Validate archive

- [ ] **24.5: Submit to TestFlight**
  - Distribute App
  - Choose TestFlight
  - Add test information
  - Submit for review

- [ ] **24.6: Add Testers**
  - Add yourself as internal tester
  - Generate public link
  - Test installation

**PR Checklist:**

- [ ] App archived successfully
- [ ] Submitted to TestFlight
- [ ] Public link generated
- [ ] Can install from TestFlight
- [ ] All features work in TestFlight build

---

## PR #25: Documentation & README

**Branch:** `docs/final-documentation`  
**Goal:** Complete all documentation  
**Complexity:** 4/10  
**Time Estimate:** 2-3 hours

### Tasks:

- [ ] **25.1: Update README**
  - Files to update: `README.md`
  - Add: Project overview
  - Add: Features list (MVP + AI)
  - Add: Tech stack
  - Add: Prerequisites
  - Add: Setup instructions
  - Add: Firebase configuration
  - Add: TestFlight link
  - Add: Screenshots

- [ ] **25.2: Create PERSONA.md**
  - Files to create: `PERSONA.md`
  - Target persona: Remote Team Professional
  - Pain points addressed
  - How each AI feature solves problems
  - Key technical decisions
  - Trade-offs made

- [ ] **25.3: Add Screenshots**
  - Take screenshots of:
    - Login/Register
    - Conversation list
    - Chat screen
    - Group chat
    - Image sharing
    - AI features (summary, action items, etc.)
    - AI Assistant
  - Add to README

- [ ] **25.4: Code Comments**
  - Review all major files
  - Add doc comments to public functions
  - Explain complex logic
  - Add TODO comments for future work

**PR Checklist:**

- [ ] README comprehensive
- [ ] PERSONA.md created
- [ ] Screenshots added
- [ ] Code well-commented
- [ ] All docs up to date

---

## PR #26: Demo Video & Final Testing

**Branch:** `final/demo-video`  
**Goal:** Create demo video and final production test  
**Complexity:** 5/10  
**Time Estimate:** 2-3 hours

### Tasks:

- [ ] **26.1: Script Demo Video**
  - Introduction (30s)
  - MVP features demo (2 min)
  - AI features demo (3 min)
  - Proactive Assistant (1 min)
  - Conclusion (30s)
  - Total: 5-7 minutes

- [ ] **26.2: Record Demo**
  - Use 2 devices side-by-side
  - Show real-time sync clearly
  - Demonstrate offline scenario
  - Show all AI features
  - Professional narration

- [ ] **26.3: Edit & Upload**
  - Edit video (transitions, callouts)
  - Add titles and annotations
  - Upload to YouTube/Loom
  - Get shareable link

- [ ] **26.4: Final Production Testing**
  - Install from TestFlight fresh
  - Test ALL features
  - Test with 2-3 friends
  - Document any final bugs

- [ ] **26.5: Prepare Submission**
  - GitHub repo public
  - README complete
  - Demo video linked
  - TestFlight link ready
  - PERSONA.md ready

**PR Checklist:**

- [ ] Demo video completed (5-7 min)
- [ ] Video uploaded and accessible
- [ ] All features tested in production
- [ ] GitHub repo ready
- [ ] Ready for final submission

---

## Final Submission Checklist (Sunday 10:59 PM)

### Required Deliverables:

- [ ] **1. GitHub Repository**
  - Public repo with all code
  - Comprehensive README
  - PERSONA.md document
  - architecture.md, PRD.md, tasks.md

- [ ] **2. Demo Video (5-7 minutes)**
  - Real-time messaging (2 devices)
  - Group chat with 3+ users
  - Offline scenario
  - App lifecycle handling
  - All 5 AI features
  - Proactive Assistant

- [ ] **3. Deployed Application**
  - iOS: TestFlight public link

- [ ] **4. Persona Document**
  - 1-page explanation

- [ ] **5. Social Post**
  - Posted on Twitter/LinkedIn
  - Tagged @GauntletAI
  - Demo video or screenshots
  - Brief description

---

## Success Metrics

### MVP (24 Hours):

- [ ] User authentication
- [ ] One-on-one messaging
- [ ] Real-time delivery (<500ms)
- [ ] Optimistic UI (<100ms)
- [ ] Message persistence (offline)
- [ ] Read receipts
- [ ] Typing indicators
- [ ] Online/offline presence
- [ ] Group chat (3+ users)
- [ ] Image sharing
- [ ] Push notifications

### AI Features (Days 2-7):

- [ ] Thread summarization
- [ ] Action item extraction
- [ ] Priority message detection
- [ ] Smart search
- [ ] Decision tracking
- [ ] Proactive Assistant

### Performance:

- [ ] Message send: <100ms
- [ ] Message delivery: <500ms
- [ ] App cold start: <2s
- [ ] AI features: <3s

---

## Complexity Distribution Summary

**Total PRs:** 26  
**Simple (1-4):** 7 PRs  
**Moderate (5-7):** 19 PRs  
**Complex (8-10):** 0 PRs ✅

**Total Estimated Time:** 52-71 hours over 7 days

All tasks properly scoped with complexity ≤7!
