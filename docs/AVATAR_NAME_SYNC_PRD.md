# Product Requirements Document: Avatar and Name Syncing Fix

## Executive Summary

This PRD addresses critical synchronization issues where user avatar and display name changes do not properly persist and sync across all views in the messageAI iOS application. The issue affects both built-in avatar selections and display name changes, creating an inconsistent user experience.

## Problem Statement

### Current Broken Behavior

**Built-in Avatar Issues:**
- When a user selects a built-in colored circle avatar, the selection does not persist to Firestore
- Built-in avatars appear correctly in the main conversations list
- Built-in avatars do NOT appear in chat message bubbles (one-on-one or group)
- Custom photo uploads work correctly everywhere
- The built-in avatar selection path is completely broken for chat views

**Display Name Issues:**
- When a user changes their display name, it appears on other screens immediately
- However, the change does not save in the user's profile section
- When returning to profile, the old name is shown
- Display name sync is unidirectional (works one way but not bidirectionally)

### Expected Correct Behavior

**For Built-in Avatars:**
- Selecting a built-in avatar should immediately:
  - Save `avatarType: "built_in"` and `avatarId: "[avatar_id]"` to Firestore users collection
  - Appear in profile where selected
  - Appear in main conversations list
  - Appear on message bubbles in all chat types (direct and group)
  - Sync to other users within 2-3 seconds
  - Persist when navigating away and back

**For Display Names:**
- Changing display name should immediately:
  - Save new name to Firestore users collection
  - Appear in profile section where changed
  - Appear in all conversations list
  - Appear on all message bubbles
  - Sync to other users within 2-3 seconds  
  - Persist when navigating away and back to profile

**For Real-time Sync:**
- All changes should propagate via Firestore listeners
- Updates should appear within 2-3 seconds for all users
- No manual refresh or app restart should be needed

## Root Cause Analysis

### Issue 1: User Model Serialization
**Location:** `/messageAI/Models/User.swift`

- **Lines 76-95**: `toDictionary()` method does NOT include `avatarType` and `avatarId` fields
- **Lines 118-130**: `CodingKeys` enum does NOT include `avatarType` and `avatarId`
- **Impact**: Even though ProfileEditingViewModel writes these fields to Firestore, when User objects are created or updated elsewhere, these fields are lost
- **Severity**: Critical - prevents persistence of built-in avatar selections

### Issue 2: Missing Avatar Information in Messages
**Location:** `/messageAI/Models/Message.swift`

- **Lines 12-32**: Message model only has `senderPhotoURL` field
- **Missing**: `senderAvatarType` and `senderAvatarId` fields
- **Impact**: Messages don't carry enough information to display built-in avatars
- **Severity**: Critical - prevents display of built-in avatars in chats

### Issue 3: Chat Message Avatar Rendering
**Location:** `/messageAI/Views/Chat/MessageBubbleView.swift`

- **Lines 228-257**: Avatar view only checks for `message.senderPhotoURL`
- **Missing**: Logic to check for and render built-in avatars
- **Impact**: Built-in avatars never display in message bubbles
- **Severity**: Critical - user-facing bug

### Issue 4: Conversation List Avatar Rendering
**Location:** `/messageAI/Views/Conversations/ConversationRowView.swift`

- **Lines 84-109**: Avatar view only checks for `participant?.photoURL`
- **Missing**: Logic to check for and render built-in avatars from user document
- **Impact**: May not consistently show built-in avatars in conversations list
- **Severity**: High - user-facing inconsistency

### Issue 5: Message Creation Missing Avatar Data
**Location:** `/messageAI/Views/Chat/ChatView.swift`

- **Lines 418-425, 436-444**: When sending messages, only passes `participant?.photoURL`
- **Missing**: Checking for and passing `avatarType` and `avatarId`
- **Impact**: Messages created without built-in avatar information
- **Severity**: Critical - breaks avatar display in chats

### Issue 6: Conversation Creation Missing Avatar Data
**Location:** `/messageAI/Services/FirestoreService.swift`

- **Lines 150-156, 185-191**: When creating ParticipantDetail, only uses `user.photoURL`
- **Missing**: Checking for and including built-in avatar information
- **Impact**: Conversations created without complete avatar data
- **Severity**: High - affects conversation list display

## Database Schema Requirements

### Users Collection Schema
Each user document MUST contain:
```typescript
{
  id: string,
  email: string,
  displayName: string,
  photoURL: string | null,          // For custom photos
  avatarType: "built_in" | "custom" | null,
  avatarId: string | null,          // For built-in avatars
  isOnline: boolean,
  lastSeen: Date,
  fcmToken: string | null,
  createdAt: Date,
  preferences: {
    aiEnabled: boolean,
    notificationSettings: { [key: string]: boolean }
  }
}
```

### Messages Collection Schema Enhancement
Each message document MUST contain:
```typescript
{
  // ... existing fields ...
  senderPhotoURL: string | null,    // For custom photos
  senderAvatarType: "built_in" | "custom" | null,
  senderAvatarId: string | null     // For built-in avatars
}
```

### Conversations Collection ParticipantDetail Enhancement
Each participantDetails entry MUST contain:
```typescript
{
  displayName: string,
  photoURL: string | null,          // For custom photos
  avatarType: "built_in" | "custom" | null,
  avatarId: string | null           // For built-in avatars
}
```

## Data Flow Diagrams

### Built-in Avatar Selection Flow
```
User selects built-in avatar
    ↓
ProfileEditingViewModel.updateProfilePicture()
    ↓
Firestore users/{userId}.update({
  avatarType: "built_in",
  avatarId: "blue_circle"
})
    ↓
Firestore conversations/{convId}.update({
  participantDetails.{userId}.avatarType: "built_in",
  participantDetails.{userId}.avatarId: "blue_circle",
  participantDetails.{userId}.photoURL: DELETE
})
    ↓
All screens listening to user document update via snapshot listener
    ↓
ProfileView: Shows selected built-in avatar
ConversationsView: Shows built-in avatar in list
ChatView: New messages include avatar type/ID
MessageBubbleView: Renders built-in avatar for all messages
```

### Display Name Change Flow
```
User edits display name
    ↓
ProfileEditingViewModel.updateDisplayName()
    ↓
Firestore users/{userId}.update({
  displayName: "New Name"
})
    ↓
Firestore conversations/{convId}.update({
  participantDetails.{userId}.displayName: "New Name"
})
    ↓
All screens listening to user document update via snapshot listener
    ↓
ProfileView: Shows new name immediately (must read from Firestore)
ConversationsView: Shows new name in list
ChatView: New messages use new name
```

### Real-time Sync Flow
```
User A changes avatar/name
    ↓
Firestore users/{userA}.updated
    ↓
Firestore listeners fire on:
  - User A's devices (profile refresh)
  - All conversations containing User A
    ↓
User B's device receives conversation update
    ↓
User B sees:
  - Updated avatar/name in conversations list (within 2-3 seconds)
  - Updated avatar/name in active chat (within 2-3 seconds)
```

## Component Requirements

### New Component: UserAvatarView
**Purpose**: Single reusable component that handles rendering all avatar types

**Inputs:**
- `userId: String?` - Optional user ID to fetch from Firestore
- `user: User?` - Optional direct user object
- `avatarType: AvatarType?` - Built-in or custom
- `avatarId: String?` - Built-in avatar identifier
- `photoURL: String?` - Custom photo URL
- `displayName: String` - For fallback initials
- `size: CGFloat` - Dimensions
- `showOnlineIndicator: Bool` - Whether to show online status

**Logic:**
```swift
1. Check avatarType:
   - If .builtIn:
     - Validate avatarId exists
     - Look up BuiltInAvatar from BuiltInAvatars.avatar(for: avatarId)
     - Render BuiltInAvatarView
   - If .custom:
     - Validate photoURL exists
     - Render AsyncImage with photoURL
   - If nil/none:
     - Render circle with displayName initials
     
2. Optionally overlay online indicator if showOnlineIndicator == true
```

**Usage locations:**
- ProfileView
- ConversationRowView
- MessageBubbleView
- GroupCreationView
- UserPickerView

### Updated Component: MessageBubbleView
**Changes needed:**
- Replace current avatar rendering logic (lines 228-257)
- Use new UserAvatarView component
- Pass `senderAvatarType`, `senderAvatarId`, `senderPhotoURL` to UserAvatarView

### Updated Component: ConversationRowView
**Changes needed:**
- Replace current avatar rendering logic (lines 84-109)
- Fetch complete user object from Firestore (not just participant detail)
- Use new UserAvatarView component with full user data

### Updated ViewModel: ProfileEditingViewModel
**No changes needed** - Already correctly writes to Firestore

### Updated Service: FirestoreService
**Changes needed:**
- Lines 150-156: When creating ParticipantDetail, include avatarType and avatarId
- Lines 185-191: When creating group ParticipantDetail, include avatarType and avatarId

## Implementation Tasks Breakdown

All tasks MUST have complexity score < 7. Each task is discrete and manageable.

### Task 1: Fix User Model Serialization (Complexity: 3)
**File:** `/messageAI/Models/User.swift`
**Changes:**
- Add `avatarType` and `avatarId` to `toDictionary()` method
- Add `avatarType` and `avatarId` to `CodingKeys` enum
**Acceptance criteria:**
- User objects serialize with avatar fields
- User objects deserialize with avatar fields from Firestore

### Task 2: Update ParticipantDetail Model (Complexity: 4)
**File:** `/messageAI/Models/Conversation.swift`
**Changes:**
- Add `avatarType: AvatarType?` field to ParticipantDetail
- Add `avatarId: String?` field to ParticipantDetail
- Update `toDictionary()` to include new fields
**Acceptance criteria:**
- ParticipantDetail can store avatar type and ID
- Serialization includes avatar fields

### Task 3: Update Message Model (Complexity: 4)
**File:** `/messageAI/Models/Message.swift`
**Changes:**
- Add `senderAvatarType: AvatarType?` field
- Add `senderAvatarId: String?` field
- Update initializer to accept new parameters
- Update `toDictionary()` to include new fields
**Acceptance criteria:**
- Messages can carry sender avatar type and ID
- Serialization includes avatar fields

### Task 4: Create UserAvatarView Component (Complexity: 5)
**New file:** `/messageAI/Views/Shared/UserAvatarView.swift`
**Implementation:**
- Create view accepting all avatar-related parameters
- Implement logic to handle built-in, custom, and fallback avatars
- Support optional online indicator overlay
- Match existing avatar styling
**Acceptance criteria:**
- Component renders built-in avatars correctly
- Component renders custom photos correctly
- Component renders fallback initials correctly
- Supports all required sizes

### Task 5: Update FirestoreService for Avatar Data (Complexity: 5)
**File:** `/messageAI/Services/FirestoreService.swift`
**Changes:**
- Update createDirectConversation to include avatar fields in ParticipantDetail
- Update createGroupConversation to include avatar fields in ParticipantDetail
**Acceptance criteria:**
- New conversations created with complete avatar data
- All participant details include avatar type and ID when applicable

### Task 6: Update ChatView Message Sending (Complexity: 6)
**File:** `/messageAI/Views/Chat/ChatView.swift`
**Changes:**
- When sending text messages, include senderAvatarType and senderAvatarId
- When sending image messages, include senderAvatarType and senderAvatarId
- Pull avatar data from current user in authViewModel
**Acceptance criteria:**
- Text messages created with sender avatar data
- Image messages created with sender avatar data
- Built-in avatar selections propagate to new messages

### Task 7: Update ChatViewModel Message Creation (Complexity: 5)
**File:** `/messageAI/ViewModels/ChatViewModel.swift`
**Changes:**
- Update sendMessage signature to accept avatarType and avatarId
- Update sendImageMessage signature to accept avatarType and avatarId
- Pass avatar data when creating Message objects
**Acceptance criteria:**
- Messages created with avatar type and ID
- Avatar data properly serialized to Firestore

### Task 8: Update MessageBubbleView Avatar (Complexity: 4)
**File:** `/messageAI/Views/Chat/MessageBubbleView.swift`
**Changes:**
- Replace avatar rendering logic (lines 228-257)
- Use new UserAvatarView component
- Pass message.senderAvatarType, message.senderAvatarId, message.senderPhotoURL
**Acceptance criteria:**
- Built-in avatars display in message bubbles
- Custom photos still display correctly
- Fallback initials work for no avatar

### Task 9: Update ConversationRowView Avatar (Complexity: 6)
**File:** `/messageAI/Views/Conversations/ConversationRowView.swift`
**Changes:**
- Replace avatar rendering logic (lines 84-109)
- Use new UserAvatarView component
- Pass participant avatar data from conversation.participantDetails
**Acceptance criteria:**
- Built-in avatars display in conversation list
- Custom photos still display correctly
- Online indicator still works

### Task 10: Add Firestore Listener to ProfileView (Complexity: 5)
**File:** `/messageAI/Views/Profile/ProfileView.swift`
**Changes:**
- Add real-time listener for current user document changes
- Update avatar display when user document changes
- Update display name when user document changes
**Acceptance criteria:**
- Profile refreshes when user data changes in Firestore
- Avatar updates appear without navigation away/back
- Name updates appear without navigation away/back

### Task 11: Update GroupCreationView Avatar (Complexity: 3)
**File:** `/messageAI/Views/Conversations/GroupCreationView.swift`
**Changes:**
- Replace avatar rendering for user selection
- Use new UserAvatarView component
**Acceptance criteria:**
- Built-in avatars display in user selection
- Custom photos still display correctly

### Task 12: Update UserPickerView Avatar (Complexity: 3)
**File:** `/messageAI/Views/Conversations/UserPickerView.swift`
**Changes:**
- Replace avatar rendering for user selection
- Use new UserAvatarView component
**Acceptance criteria:**
- Built-in avatars display in user picker
- Custom photos still display correctly

## Testing Requirements

### Unit Testing
**Not required** - Focus on manual simulator testing per user requirements

### Manual Testing with iOS Simulator MCP

#### Test Case 1: Built-in Avatar Selection and Sync
**Setup:** 2-3 simulators with different users

**Steps:**
1. User A: Open profile, select built-in blue circle avatar
2. Verify: Database shows `users/{userA}.avatarType = "built_in"`, `avatarId = "blue_circle"`
3. Verify: Profile immediately shows blue circle
4. User A: Navigate to conversations list
5. Verify: Blue circle shows in list
6. User A: Open group chat, send message
7. Verify: Message bubble shows blue circle avatar
8. User B: Check conversation list
9. Verify: User A appears with blue circle avatar (within 2-3 seconds)
10. User B: Open chat with User A
11. Verify: All User A messages show blue circle avatar
12. Take screenshots at each step

**Expected result:** Blue circle avatar appears everywhere, syncs within 2-3 seconds

#### Test Case 2: Custom Photo Selection and Sync
**Setup:** Use User A from Test Case 1

**Steps:**
1. User A: Open profile, upload custom photo
2. Verify: Database shows `users/{userA}.avatarType = "custom"`, `photoURL = "https://..."`
3. Verify: Profile immediately shows custom photo
4. User A: Navigate to conversations list
5. Verify: Custom photo shows in list
6. User A: Send message in chat
7. Verify: Message bubble shows custom photo
8. User B: Check conversation list
9. Verify: User A appears with custom photo (replaces blue circle)
10. User B: Check chat messages
11. Verify: User A messages show custom photo
12. Take screenshots

**Expected result:** Custom photo replaces built-in avatar everywhere

#### Test Case 3: Switch Between Avatar Types
**Setup:** User A with custom photo from Test Case 2

**Steps:**
1. User A: Select built-in red circle avatar
2. Verify: Database updated to red circle
3. Verify: Everywhere shows red circle (not custom photo)
4. User A: Upload new custom photo
5. Verify: Database updated to new custom photo
6. Verify: Everywhere shows new custom photo
7. User A: Select built-in green circle
8. Verify: Database updated to green circle
9. Verify: Everywhere shows green circle
10. Take screenshots

**Expected result:** Seamless switching between types, no stale data

#### Test Case 4: Display Name Change and Sync
**Setup:** User A (current name "Test2")

**Steps:**
1. User A: Open profile, change name to "Sarah Chen"
2. Verify: Database shows `users/{userA}.displayName = "Sarah Chen"`
3. Verify: Profile immediately shows "Sarah Chen"
4. User A: Navigate away from profile and back
5. **Critical:** Verify profile STILL shows "Sarah Chen" (not reverted)
6. User A: Check conversations list
7. Verify: Shows "Sarah Chen"
8. User A: Send message
9. Verify: Message shows "Sarah Chen"
10. User B: Check conversation list
11. Verify: User A shows as "Sarah Chen" (within 2-3 seconds)
12. User B: Check messages
13. Verify: User A messages show "Sarah Chen"
14. Take screenshots

**Expected result:** Name persists in profile, syncs everywhere

#### Test Case 5: Database Consistency Check
**Steps:**
1. Make various avatar changes (built-in → custom → built-in)
2. After each change, screenshot Firestore console
3. Make various name changes
4. After each change, screenshot Firestore console
5. Verify database always matches UI
6. Verify no orphaned or conflicting data

**Expected result:** Database perfectly matches UI at all times

#### Test Case 6: Multiple Rapid Changes
**Steps:**
1. User A: Rapidly select 3-4 different built-in avatars (1-2 seconds apart)
2. Verify: Database eventually shows final selection
3. Verify: All UIs show final selection (no intermediate states stuck)
4. User A: Rapidly change name 3-4 times
5. Verify: Database shows final name
6. Verify: All UIs show final name

**Expected result:** System handles rapid changes gracefully, converges to final state

## Performance Requirements

- **Avatar Changes**: Must appear in local UI within 500ms
- **Remote Sync**: Must appear on other users' devices within 2-3 seconds
- **Database Writes**: Must complete within 1 second
- **No UI Blocking**: All operations must be asynchronous
- **Memory**: Avatar images should be cached appropriately
- **Network**: Must handle offline gracefully (show last known state)

## Security Requirements

- **User Isolation**: Users can only edit their own profile
- **Validation**: Avatar IDs must be validated against BuiltInAvatars.all
- **Photo Upload**: Custom photos must use secure Firebase Storage with proper auth
- **Data Integrity**: All Firestore operations must use transactions where appropriate

## Rollout Plan

1. **Phase 1**: Fix data models and serialization (Tasks 1-3)
2. **Phase 2**: Create reusable avatar component (Task 4)
3. **Phase 3**: Update services and view models (Tasks 5-7)
4. **Phase 4**: Update all UI views (Tasks 8-12)
5. **Phase 5**: Comprehensive testing with iOS Simulator MCP
6. **Phase 6**: User acceptance and deployment

## Success Metrics

- ✅ Built-in avatar selections persist to database
- ✅ Built-in avatars display in all views
- ✅ Custom photos continue to work everywhere
- ✅ Display name changes persist in profile
- ✅ All changes sync within 2-3 seconds
- ✅ No build errors or warnings
- ✅ All test cases pass
- ✅ Database matches UI at all times

## References

- Firebase Firestore Documentation: https://firebase.google.com/docs/firestore
- SwiftUI AsyncImage: https://developer.apple.com/documentation/swiftui/asyncimage
- Swift Codable: https://developer.apple.com/documentation/swift/codable

