# MessageAI - Product Requirements Document

**Project**: MessageAI - Intelligent Messaging for Remote Teams  
**Platform**: iOS (Swift/SwiftUI)  
**Timeline**: 7-day development sprint  
**Target User**: Remote Team Professionals (engineers, designers, PMs)

---

## Executive Summary

MessageAI is a production-quality messaging application designed specifically for remote teams who need to cut through communication noise. It combines WhatsApp-level messaging reliability with AI features that automatically surface decisions, track action items, detect urgent messages, and help teams stay aligned without constant context-switching.

**Core Value Proposition**: A messaging app that feels as reliable as iMessage but works like having a smart assistant watching every conversation to help your team never miss what matters.

---

## Product Vision

### The Problem

Remote teams face three critical communication challenges:

1. **Thread Overwhelm**: Conversations spiral into hundreds of messages, making it impossible to extract key information
2. **Decision Archaeology**: Team decisions get buried in chat history, forcing people to scroll through endless threads
3. **Action Item Amnesia**: Tasks mentioned in conversations are forgotten or never tracked
4. **Priority Blindness**: Urgent messages get lost in the noise of routine chat
5. **Context Switching**: Teams waste time coordinating schedules across multiple messages

### The Solution

MessageAI solves these problems through intelligent AI features built on top of rock-solid messaging infrastructure:

- **Thread Summarization**: 3-bullet summaries of long conversations
- **Action Item Extraction**: Automatic tracking of tasks with owners
- **Priority Detection**: Auto-flagging of urgent messages
- **Decision Tracking**: Automatic logging of team decisions
- **Smart Search**: Find messages by meaning, not just keywords
- **Proactive Assistant**: Detects scheduling needs and offers help

### Success Criteria

A small remote team can coordinate a product launch entirely through MessageAI, with AI automatically surfacing decisions, tracking action items, and helping team members catch up on missed conversations in seconds instead of minutes.

---

## Target User: Remote Team Professional

### Persona: Alex - Remote Software Engineer

**Demographics**:
- Age: 28-35
- Role: Senior Software Engineer at distributed startup
- Team size: 8-12 people across 4 time zones
- Works from home full-time

**Daily Workflow**:
- Starts day catching up on overnight messages (30+ unread)
- Participates in 3-5 group conversations simultaneously
- Coordinates with design, product, and engineering teams
- Makes technical decisions through async chat
- Schedules meetings across time zones

**Pain Points**:
1. Spends 45 minutes each morning reading overnight messages
2. Misses important decisions buried in 200-message threads
3. Forgets action items mentioned casually in chat
4. Can't quickly determine which messages need immediate attention
5. Wastes time coordinating meeting times across conversations

**Goals**:
- Catch up on important conversations in under 5 minutes
- Never miss critical decisions or action items
- Respond to urgent messages within 10 minutes
- Reduce time spent on meeting coordination

---

## User Stories

### MVP (24 Hours): Core Messaging

**As a remote team member, I want to...**

1. Create an account and log in securely
2. Send text messages that arrive instantly (<500ms)
3. See messages even when offline
4. Know if my messages were delivered and read
5. See when teammates are typing
6. Know which teammates are online/offline
7. Create group chats with my team (3+ people)
8. Send images from my photo library or camera
9. Receive push notifications for new messages
10. Have conversations persist when I close the app

### Post-MVP (Days 2-7): AI Features

**As a remote team member, I want to...**

11. Summarize long conversations in 3 bullet points
12. Automatically extract action items with owners
13. Have urgent messages flagged automatically
14. Search conversations by meaning, not just keywords
15. See all team decisions logged automatically
16. Get proactive help with scheduling coordination

---

## Technical Architecture

### Platform: iOS Native (Swift/SwiftUI)

**Why iOS-first:**
- Single platform focus for 7-day timeline
- SwiftUI provides rapid development
- TestFlight enables easy beta testing
- Can expand to Android post-launch

### Backend: Firebase

**Services Used:**

1. **Firebase Authentication**
   - Email/password authentication
   - Google Sign-In
   - User profile storage

2. **Cloud Firestore**
   - Conversation metadata
   - Message history
   - User profiles
   - AI insights storage
   - Offline persistence built-in

3. **Firebase Realtime Database**
   - Typing indicators (ephemeral)
   - Online presence (ephemeral)
   - Sub-50ms updates

4. **Firebase Storage**
   - Image uploads
   - User avatars

5. **Firebase Cloud Messaging**
   - Push notifications
   - Background delivery

6. **Firebase Cloud Functions**
   - AI feature processing
   - Notification triggers
   - Priority detection

### Local Storage: Core Data

**Purpose:**
- Offline message caching
- Fast initial load
- Sync queue for offline sends
- Unread count tracking

### AI: Anthropic Claude

**Model**: Claude 3.5 Sonnet (claude-3-5-sonnet-20241022)

**Use Cases:**
- Thread summarization
- Action item extraction
- Priority classification (ambiguous cases)
- Decision detection
- Scheduling need detection
- Smart search (future: embeddings)

---

## Feature Specifications

### 1. Authentication

**Requirements:**
- Email/password signup and login
- Google Sign-In integration
- Display name from Google profile or email prefix
- Session persistence (stays logged in)
- User profile creation in Firestore

**User Flow:**
1. User opens app → sees login screen
2. User enters email/password OR taps "Sign in with Google"
3. On first signup, system creates user profile
4. User lands on conversation list

**Edge Cases:**
- Invalid email format → show error
- Password too short (< 8 chars) → show error
- Google Sign-In cancelled → return to login
- Network error during auth → show retry option

### 2. Conversation List

**Requirements:**
- Display all conversations user participates in
- Show last message preview
- Show timestamp (relative: "5m ago", "Yesterday")
- Show unread count badge
- Show online status indicator (green/gray dot)
- Pull to refresh
- Empty state when no conversations
- Floating action button for new conversation

**Sorting**: Most recent activity first (lastMessageTimestamp DESC)

**Performance**: Load from Core Data immediately, then sync from Firestore

**User Flow:**
1. User sees list of conversations
2. User taps conversation → opens chat
3. User taps "+" → opens user picker
4. User selects another user → creates conversation → opens chat

### 3. Chat Screen

**Requirements:**
- Real-time message display (updates < 500ms)
- Optimistic UI (sent messages appear instantly)
- Message bubbles (own messages right-aligned blue, others left-aligned gray)
- Sender name for group chats
- Timestamps (relative: "2m ago")
- Status indicators: sending (clock) → sent (checkmark) → delivered (double checkmark) → read (blue double checkmark)
- Text input with send button
- Image picker button (camera and photo library)
- Scroll to bottom on new message
- Load more messages on scroll to top (pagination)
- Typing indicator ("Alice is typing...")
- Online status in header

**Message Flow:**
1. User types message
2. User taps send
3. Message appears immediately with "sending" status
4. Background: Upload to Firestore, get server ID
5. Status updates: sent → delivered → read
6. Other users see message appear in real-time

**Offline Behavior:**
- User sends message while offline
- Message appears with "sending" status
- Saved to Core Data with isSynced=false
- When reconnected, uploads to Firestore automatically
- Status updates to "sent"

### 4. Group Chat

**Requirements:**
- Support 3+ participants
- Display sender name for all messages
- Show sender avatar next to message
- Read receipts show count: "Read by 3 of 5"
- Typing indicators handle multiple users: "Alice, Bob, and 2 others are typing..."
- Group name or auto-generated: "Alice, Bob, +2"
- Group info screen showing all participants

**Creation Flow:**
1. User taps "+" on conversations list
2. Select "New Group" option
3. Select 2+ other users (checkboxes)
4. Optional: Enter group name
5. Tap "Create" → group created → opens chat

### 5. Image Sharing

**Requirements:**
- Select from photo library
- Capture new photo with camera
- Compress images before upload (JPEG quality 0.8)
- Show upload progress indicator
- Display images in chat with proper sizing
- Tap to view full screen
- Full screen: zoom, pan, share/save

**Upload Flow:**
1. User taps camera button in chat
2. User selects photo or captures new
3. Image appears in chat with upload progress
4. Background: Compress → Upload to Storage → Get URL
5. Send message with type="image" and imageURL
6. Other users see image load

**Offline Handling:**
- If offline, store image locally
- Queue for upload when reconnected
- Show "waiting to upload" status

### 6. Push Notifications

**Requirements:**
- Request permission on first launch
- Foreground: Show banner notification
- Background: System notification with sound
- Tap notification → open conversation
- Badge count shows total unread
- Don't notify for currently open conversation

**Notification Content:**
- Title: Sender name
- Body: Message text (truncated to 100 chars)
- Data: conversationId, messageId for deep linking

### 7. Read Receipts

**Implementation:**
- Each user has lastSeenAt timestamp in conversation
- Updated when user views conversation
- Message marked read if recipientLastSeenAt >= message.createdAt
- UI shows status indicators for own messages
- Group chat shows count: "Read by 3 of 5"

### 8. Typing Indicators

**Implementation:**
- Use Firebase Realtime Database for <50ms updates
- Set typing/conversationId/userId when typing starts
- Clear on blur or 3 seconds of inactivity
- Subscribe to typing status for conversation
- Display: "Alice is typing..." (1 user) or "Alice, Bob are typing..." (2+ users)

### 9. Online Presence

**Implementation:**
- Use Firebase Realtime Database
- Set presence/userId = { online: true, lastSeen: timestamp }
- Use onDisconnect() to auto-set offline
- Update on app foreground/background
- Display: Green dot (online) or gray dot with "last seen 5m ago"

### 10. Offline Support

**Strategy**: Firestore offline persistence + Core Data sync queue

**Capabilities:**
- View all past messages offline
- Send messages offline (queued)
- Messages auto-sync on reconnect
- No message loss ever

**Sync Flow:**
1. User sends while offline
2. Insert to Core Data with isSynced=false
3. Add to in-memory sync queue
4. Show "sending" status
5. When online, process queue
6. Upload each message to Firestore
7. Update Core Data with server ID, isSynced=true
8. Update UI to "sent" status

**Retry Logic:**
- Max 3 retry attempts per message
- Exponential backoff (1s, 2s, 4s)
- After 3 failures, mark as "failed"
- Show error icon, allow manual retry

---

## AI Feature Specifications

### AI Feature 1: Thread Summarization

**Goal**: Help users catch up on long conversations in seconds

**Trigger**: User taps "Summarize" button in chat toolbar

**Implementation**:
1. Retrieve last 100 messages from conversation
2. Format as transcript: "SenderName: Message text"
3. Call Claude API with prompt: "Summarize this team conversation in 3 concise bullet points"
4. Display result as AI Insight card in chat
5. Store in Firestore for persistence

**Output Format**:
- 3 bullet points
- Each 1-2 sentences max
- Actionable and specific

**Performance**: Generate within 3 seconds

**Example**:
```
• Team decided to use PostgreSQL instead of MongoDB for better transaction support
• Alice will prototype the new dashboard design by Friday EOD
• Deployment scheduled for next Tuesday 2pm, Bob confirmed infrastructure ready
```

### AI Feature 2: Action Item Extraction

**Goal**: Never lose track of tasks mentioned in conversations

**Trigger**: User taps "Action Items" button in chat toolbar

**Implementation**:
1. Retrieve last 100 messages
2. Format as transcript
3. Call Claude with prompt: "Extract action items from this conversation. Format each as: 'Owner: Task (deadline if mentioned)'"
4. Display as bulleted list in AI Insight card
5. Store in Firestore

**Output Format**:
- Owner name (bold)
- Task description
- Deadline if mentioned

**Performance**: Generate within 3 seconds

**Example**:
```
• Alice: Design mockups for user settings page (by Friday)
• Bob: Review PR #234 and provide feedback
• Carol: Schedule follow-up meeting with stakeholders (this week)
```

### AI Feature 3: Priority Message Detection

**Goal**: Never miss urgent messages in the noise

**Trigger**: Automatic on every new message

**Implementation**:
1. Pattern matching for obvious keywords: "urgent", "ASAP", "critical", "emergency", "deadline", "immediately"
2. If keyword match → mark priority=true
3. If ambiguous, call Claude: "Rate urgency 1-5 scale" → if 4+, mark priority
4. Update message document with priority flag
5. Send push notification even if conversation muted

**UI Indicators**:
- Red flag icon next to message
- Red border around message bubble
- Notification uses critical alert sound

**Performance**: Detection within 500ms (don't slow message delivery)

**False Positive Target**: < 10%

### AI Feature 4: Smart Search

**Goal**: Find messages by meaning, not just keywords

**MVP Implementation**: Keyword search
1. Query Core Data: `text LIKE '%query%'`
2. Return top 50 results
3. Sort by relevance (creation date DESC)
4. Group by conversation
5. Highlight query in results

**Future Enhancement**: Semantic search with embeddings
1. Generate embeddings for messages (Claude or OpenAI)
2. Store in vector database (Pinecone or Firebase)
3. Query by similarity instead of keywords

**Performance**: Results within 1 second

### AI Feature 5: Decision Tracking

**Goal**: Automatic log of all team decisions

**Trigger**: Automatic on every new message

**Implementation**:
1. Pattern matching: "let's go with", "we'll use", "decided", "approved", "agreed"
2. If match, call Claude: "What was decided? Extract the decision and context"
3. Create AI Insight with type="decision"
4. Store metadata: approvedBy (if detectable), relatedMessages
5. Index in searchable decisions list

**UI**:
- Decisions tab in app (with icon)
- List view grouped by date
- Search functionality
- Tap to view in original conversation

**False Positive Target**: < 15%

**Example Decision Log**:
```
"Use PostgreSQL for database" 
- Conversation: #engineering
- Decided: 2 hours ago
- Participants: Alice, Bob, Carol
```

### AI Feature 6: Proactive Assistant

**Goal**: Detect needs and offer intelligent help

**Focus Area**: Scheduling coordination (MVP)

**Trigger**: Automatic on every new message

**Implementation**:
1. Pattern matching: "when can", "what time", "schedule", "meeting", "available", "free time"
2. If match, call Claude: "Does this conversation indicate scheduling need? Confidence level?"
3. If confidence > 80%, create suggestion insight
4. Display: "Would you like me to help find a time that works for everyone?"
5. User taps "Yes, help me"
6. Claude analyzes conversation for time mentions
7. Suggests 2-3 time slots
8. Posts as AI assistant message

**Dismissal**: User can tap "Dismiss" to hide permanently

**Future Enhancement**: Check for conflicts across all conversations

---

## Performance Requirements

### Core Messaging (MVP - Critical)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Message send (optimistic UI) | < 100ms | Time from tap to local display |
| Message delivery (online) | < 500ms | Time from send to recipient display |
| Typing indicator | < 200ms | Time from keystroke to indicator shown |
| Presence update | < 5 seconds | Time from status change to UI update |
| App cold start | < 2 seconds | Time from tap to conversation list |
| Image upload | < 5 seconds | Typical photo (3MB) |

### AI Features (Post-MVP)

| Feature | Target | Measurement |
|---------|--------|-------------|
| Summarization | < 3 seconds | API call to display |
| Action items | < 3 seconds | API call to display |
| Priority detection | < 500ms | Don't delay message delivery |
| Search results | < 1 second | Query to display |
| Decision tracking | < 500ms | Don't delay message delivery |
| Proactive suggestion | < 2 seconds | Detection to card display |

---

## Success Metrics

### MVP Checkpoint (24 Hours)

**Hard Gates** (Must Pass):
- [ ] Two users can chat in real-time across different devices
- [ ] Messages appear instantly with optimistic UI (< 100ms)
- [ ] Offline scenario works: Send 5 messages offline, reconnect, all deliver
- [ ] App lifecycle handling: Force-quit, reopen, messages persist
- [ ] Read receipts update in real-time
- [ ] Group chat works with 3+ participants
- [ ] Typing indicators appear within 200ms
- [ ] Push notifications fire (foreground minimum)

### Final Submission (Day 7)

**Required Features**:
- [ ] All MVP features working reliably
- [ ] Thread summarization (3 bullets in < 3s)
- [ ] Action item extraction (tasks with owners)
- [ ] Priority message detection (< 10% false positives)
- [ ] Smart search (keyword-based, < 1s results)
- [ ] Decision tracking (auto-log decisions)
- [ ] Proactive assistant (scheduling detection)

**Quality Metrics**:
- [ ] No crashes in production
- [ ] Works on iOS 16.0+
- [ ] Smooth performance on test devices
- [ ] Error messages are helpful
- [ ] UI feels polished (animations, spacing, colors)
- [ ] Accessible with VoiceOver

**Deployment**:
- [ ] App deployed to TestFlight
- [ ] Public TestFlight link generated
- [ ] Demo video completed (5-7 minutes)
- [ ] README with setup instructions
- [ ] PERSONA.md document

---

## Technical Constraints & Trade-offs

### Constraints

1. **7-day timeline**: Must prioritize ruthlessly
2. **iOS only**: No cross-platform for now
3. **Firebase free tier**: Monitor costs carefully
4. **Anthropic free tier**: Limited AI tokens
5. **Solo developer**: No parallel work streams
6. **TestFlight only**: No App Store submission yet

### MVP Trade-offs (Acceptable)

1. **No end-to-end encryption**: Messages stored in plaintext
2. **No message editing**: Edit/delete out of scope
3. **No voice messages**: Text and images only
4. **Basic search only**: Keyword-based initially
5. **Foreground notifications**: Background push best-effort
6. **Single device**: No multi-device sync
7. **No desktop client**: Mobile-first

### Non-Negotiable (Cannot Cut)

1. Real-time messaging (< 500ms delivery)
2. Offline support (queue and sync)
3. Read receipts
4. Group chat
5. At least 3 AI features working
6. Deployed and accessible via TestFlight

---

## Risk Mitigation

### Risk 1: 24-Hour MVP Deadline Too Aggressive

**Likelihood**: High  
**Impact**: Critical

**Mitigation**:
- Focus ruthlessly on core messaging first 12 hours
- Defer images and push notifications to hours 20-24 if needed
- Have Core Data setup ready before starting
- Test offline scenarios continuously, not at the end

### Risk 2: Offline Sync Bugs Causing Message Loss

**Likelihood**: Medium  
**Impact**: Critical

**Mitigation**:
- Use Core Data transactions for atomicity
- Never silently drop messages - always queue for retry
- Test offline scenarios early and often (Day 1)
- Add comprehensive error logging
- Keep sync logic simple and well-tested

### Risk 3: Push Notifications Not Working on Device

**Likelihood**: Medium  
**Impact**: High

**Mitigation**:
- Test on physical iOS device by Day 2 (simulator unreliable)
- Allocate buffer time for certificate debugging
- Have fallback: Foreground notifications sufficient for MVP
- Get push working by Day 3 at latest

### Risk 4: AI Features Taking Too Long

**Likelihood**: Medium  
**Impact**: Medium

**Mitigation**:
- Start with simplest feature (summarization) first
- Use straightforward prompts initially
- Reuse RAG pipeline across features
- Optimize prompts only if time permits
- Acceptable for AI features to be "good enough" not perfect

### Risk 5: Firebase/Firestore Costs Exploding

**Likelihood**: Low  
**Impact**: Medium

**Mitigation**:
- Use Core Data caching aggressively
- Set Firebase budget alerts (< $10)
- Monitor usage daily via console
- Optimize queries (limit, where clauses)
- Use RTDB for ephemeral data (typing, presence)

### Risk 6: TestFlight Approval Delays

**Likelihood**: Low  
**Impact**: Medium

**Mitigation**:
- Submit to TestFlight by Day 6 at latest
- Internal testing doesn't require review
- Have backup: Provide build instructions if needed
- Test upload process early

---

## Future Enhancements (Post-Launch)

### Phase 2: Enhanced Messaging
- Voice messages
- Video messages
- Message reactions (emoji)
- Message editing and deletion
- Reply/quote functionality
- Message forwarding
- Link previews

### Phase 3: Advanced AI
- Semantic search with vector embeddings
- Auto-generated meeting notes
- Sentiment analysis (detect team morale)
- Topic extraction and tagging
- Conflict detection across conversations
- Smart reminders (follow up on action items)

### Phase 4: Platform Expansion
- Android app (React Native or Kotlin)
- macOS app (Mac Catalyst or SwiftUI)
- Web client (React)
- Multi-device sync

### Phase 5: Enterprise Features
- Team workspaces
- Admin controls
- Usage analytics
- Export conversations
- Compliance features
- SSO integration

### Phase 6: Security & Privacy
- End-to-end encryption
- Message expiration
- Screenshot prevention
- Two-factor authentication
- Advanced user permissions

---

## Appendix: API Contracts

### Firestore Data Models

**Users Collection** (`/users/{userId}`):
```typescript
{
  id: string
  displayName: string
  email: string
  photoURL?: string
  isOnline: boolean
  lastSeen: timestamp
  fcmToken?: string
  createdAt: timestamp
}
```

**Conversations Collection** (`/conversations/{conversationId}`):
```typescript
{
  id: string
  type: "direct" | "group"
  participantIds: string[]
  participantDetails?: User[]
  lastMessageText?: string
  lastMessageTimestamp?: timestamp
  unreadCount: number
  updatedAt: timestamp
}
```

**Messages Subcollection** (`/conversations/{id}/messages/{messageId}`):
```typescript
{
  id: string
  conversationId: string
  senderId: string
  senderName: string
  senderPhotoURL?: string
  type: "text" | "image"
  text: string
  imageURL?: string
  createdAt: timestamp
  status: "sending" | "sent" | "delivered" | "read"
  deliveredTo?: string[]
  readBy?: string[]
  priority?: boolean
  isSynced: boolean
}
```

**AI Insights Subcollection** (`/conversations/{id}/insights/{insightId}`):
```typescript
{
  id: string
  type: "summary" | "action_items" | "decision" | "suggestion"
  content: string
  messageIds: string[]
  triggeredBy: string
  createdAt: timestamp
  metadata?: {
    approvedBy?: string[]
    action?: string
    confidence?: number
  }
}
```

### Realtime Database Schema

**Typing** (`/typing/{conversationId}/{userId}`):
```typescript
{
  isTyping: boolean
  timestamp: number
  // Auto-deleted after 10 seconds
}
```

**Presence** (`/presence/{userId}`):
```typescript
{
  online: boolean
  lastSeen: timestamp
  // Auto-set offline on disconnect
}
```

### Cloud Function Triggers

**sendMessageNotification**:
- Trigger: onCreate `/conversations/{id}/messages/{messageId}`
- Action: Send FCM notification to recipients (exclude sender)

**detectPriority**:
- Trigger: onCreate `/conversations/{id}/messages/{messageId}`
- Action: Analyze message, set priority flag if urgent

**detectDecision**:
- Trigger: onCreate `/conversations/{id}/messages/{messageId}`
- Action: Detect decision language, create insight if found

**proactiveScheduling**:
- Trigger: onCreate `/conversations/{id}/messages/{messageId}`
- Action: Detect scheduling need, create suggestion if confident

---

## Appendix: Development Setup

### Prerequisites
- macOS with Xcode 15+
- iOS 16.0+ test device (physical device recommended)
- Firebase account
- Anthropic API key
- Apple Developer account (for TestFlight)

### Firebase Project Setup
1. Create Firebase project: "messageai-prod"
2. Enable Authentication (Email/Password + Google)
3. Create Firestore database (test mode)
4. Enable Storage
5. Enable Cloud Messaging
6. Download GoogleService-Info.plist

### Local Development
1. Clone repository
2. Open Xcode project
3. Add GoogleService-Info.plist to project
4. Install dependencies via Swift Package Manager
5. Run on simulator or device
6. Configure Firebase Cloud Functions
7. Deploy functions: `firebase deploy --only functions`

### Testing Strategy
- Unit tests: Core business logic
- Integration tests: Firebase operations
- UI tests: Critical user flows
- Manual testing: Physical device required for push

---

## Document Version History

- v1.0 (2025-10-21): Initial PRD - Complete specification for 7-day sprint