# Message Deletion, Offline Sync, and Notification Fixes - Tasks

## Overview
Fix message deletion permissions, chats list updates, offline sync timing, typing indicator reliability, and notification consistency.

---

## Task 1: Fix Firestore Security Rule for Message Deletion
**Complexity:** 4
**Dependencies:** None
**File:** `firestore.rules`

**Description:**
Update the security rules for the messages subcollection to properly handle delete operations. Currently, the rule uses `allow read, write` which doesn't verify message ownership for deletions, causing permission denied errors.

**Changes Required:**
- Line 27-29: Replace combined `allow read, write` with separate rules
- Add `allow read:` for reading messages (authenticated users only)
- Add `allow create:` for creating messages (authenticated users only)
- Add `allow update:` for updating messages (authenticated users only)
- Add `allow delete:` for deleting messages (authenticated AND must be sender)
  - Check: `request.auth.uid == resource.data.senderId`

**Acceptance Criteria:**
- [ ] Security rule separates read, create, update, delete operations
- [ ] Delete operation verifies user is the message sender
- [ ] Rule allows authenticated users to delete their own messages
- [ ] Rule blocks users from deleting others' messages
- [ ] No syntax errors in rules file

**Testing:**
- Deploy rules: `firebase deploy --only firestore:rules`
- Verify rules compile without errors
- Test deletion doesn't throw permission error
- Test user cannot delete others' messages

---

## Task 2: Add UpdateConversationLastMessage Function to FirestoreService
**Complexity:** 3
**Dependencies:** None
**File:** `messageAI/Services/FirestoreService.swift`

**Description:**
Add a new function to update a conversation's last message after a message is deleted. This function will be called when the deleted message was the last message in the conversation.

**Changes Required:**
- Add new function after `deleteMessage()` (around line 420)
```swift
/// Update conversation's last message
/// - Parameters:
///   - conversationId: Conversation ID
///   - lastMessage: New last message
func updateConversationLastMessage(conversationId: String, lastMessage: LastMessage) async throws {
    let conversationRef = db.collection("conversations").document(conversationId)
    try await conversationRef.updateData([
        "lastMessage": lastMessage.toDictionary(),
        "updatedAt": lastMessage.timestamp
    ])
    print("✅ Updated conversation last message after deletion: \(conversationId)")
}

/// Clear conversation's last message (when no messages remain)
/// - Parameter conversationId: Conversation ID
func clearConversationLastMessage(conversationId: String) async throws {
    let conversationRef = db.collection("conversations").document(conversationId)
    try await conversationRef.updateData([
        "lastMessage": FieldValue.delete(),
        "updatedAt": Date()
    ])
    print("✅ Cleared conversation last message: \(conversationId)")
}
```

**Acceptance Criteria:**
- [ ] Function updates conversation's lastMessage field
- [ ] Function updates conversation's updatedAt field
- [ ] Function logs success
- [ ] Separate function to clear lastMessage when no messages remain
- [ ] No compilation errors

**Testing:**
- Call function manually
- Verify conversation document updates in Firestore
- Check logs for success message

---

## Task 3: Update ChatViewModel to Recalculate Last Message After Deletion
**Complexity:** 6
**Dependencies:** Task 1, Task 2
**File:** `messageAI/ViewModels/ChatViewModel.swift`

**Description:**
Modify the `deleteMessage()` function to update the conversation's last message after deleting a message. If the deleted message was the last message, find the new last message and update both Firestore and Core Data.

**Changes Required:**
- Function `deleteMessage()` around line 556-595
- After successful Firestore deletion (after line 579), add logic:
  ```swift
  // Update conversation's last message if we deleted the last message
  let wasLastMessage = message.id == messages.last?.id
  
  if wasLastMessage {
      // messages array already has deleted message removed (optimistic UI)
      if let newLastMessage = messages.last {
          // Update Firestore
          try await firestoreService.updateConversationLastMessage(
              conversationId: conversationId,
              lastMessage: LastMessage(
                  text: newLastMessage.previewText,
                  senderId: newLastMessage.senderId,
                  timestamp: newLastMessage.createdAt
              )
          )
          
          // Update Core Data
          coreDataService.updateConversationLastMessage(
              conversationId: conversationId,
              lastMessage: LastMessage(
                  text: newLastMessage.previewText,
                  senderId: newLastMessage.senderId,
                  timestamp: newLastMessage.createdAt
              )
          )
          
          print("✅ Updated last message after deletion")
      } else {
          // No messages left
          try await firestoreService.clearConversationLastMessage(conversationId: conversationId)
          print("✅ Cleared last message (no messages remain)")
      }
  }
  ```

**Acceptance Criteria:**
- [ ] Function checks if deleted message was last message
- [ ] If yes, updates conversation's lastMessage in Firestore
- [ ] If yes, updates conversation's lastMessage in Core Data
- [ ] If no messages remain, clears lastMessage
- [ ] Logs each update action
- [ ] No compilation errors

**Testing:**
- Delete last message in conversation
- Check Firestore conversation document
- Verify lastMessage field updated
- Check chats list shows new last message

---

## Task 4: Add Timing Logs to Sync Process
**Complexity:** 3
**Dependencies:** None
**File:** `messageAI/Services/SyncService.swift`

**Description:**
Add detailed timing logs to measure how quickly sync starts after network reconnection. This will help verify the sync happens within 1 second as required.

**Changes Required:**
- Function `setupNetworkListener()` around line 35-44
```swift
private func setupNetworkListener() {
    NotificationCenter.default.publisher(for: .networkConnected)
        .sink { [weak self] notification in
            let receivedAt = Date()
            print("📡 Network connected notification received at \(receivedAt)")
            
            Task {
                let syncStartedAt = Date()
                let delay = syncStartedAt.timeIntervalSince(receivedAt)
                print("🔄 Starting sync at \(syncStartedAt) (delay: \(String(format: "%.3f", delay))s)")
                
                await self?.processPendingMessages()
                
                let syncEndedAt = Date()
                let duration = syncEndedAt.timeIntervalSince(syncStartedAt)
                print("✅ Sync completed at \(syncEndedAt) (duration: \(String(format: "%.3f", duration))s)")
            }
        }
        .store(in: &cancellables)
}
```

**Acceptance Criteria:**
- [ ] Logs timestamp when notification received
- [ ] Logs timestamp when sync starts
- [ ] Logs delay between notification and sync start
- [ ] Logs total sync duration
- [ ] Uses millisecond precision (3 decimal places)
- [ ] No compilation errors

**Testing:**
- Go offline, send messages, go online
- Check logs for timestamps
- Verify delay is < 1 second
- Verify all timing information is logged

---

## Task 5: Add Double-Check to Typing Indicator Functions
**Complexity:** 4
**Dependencies:** None
**File:** `messageAI/ViewModels/ChatViewModel.swift`

**Description:**
Add additional network state checks to typing indicator functions to make them 100% bulletproof. Add checks before AND during typing operations to catch race conditions.

**Changes Required:**

**Change 1: Update `updateTypingStatus()` around line 219:**
```swift
func updateTypingStatus(isTyping: Bool, currentUserId: String) {
    guard let conversationId = conversationId else { return }
    
    // Double-check offline state (both flags)
    guard networkMonitor.isConnected && !networkMonitor.debugOfflineMode else {
        print("⚠️ Offline: Not sending typing update (double-check)")
        return
    }
    
    Task {
        // Triple-check before actual send (catch race conditions)
        guard networkMonitor.isConnected && !networkMonitor.debugOfflineMode else {
            print("⚠️ Network went offline before sending typing update")
            return
        }
        
        await realtimeDBService.setTyping(
            conversationId: conversationId,
            userId: currentUserId,
            isTyping: isTyping
        )
    }
}
```

**Change 2: Update `subscribeToTyping()` around line 211:**
```swift
private func subscribeToTyping(conversationId: String, currentUserId: String) {
    typingTask = Task {
        for await typingUserIds in realtimeDBService.observeTyping(conversationId: conversationId) {
            // Double-check offline state (both flags)
            guard networkMonitor.isConnected && !networkMonitor.debugOfflineMode else {
                self.typingUsers = []
                print("⚠️ Offline: Not displaying typing indicators (double-check)")
                continue
            }
            
            // Filter out current user
            let otherUsersTyping = typingUserIds.filter { $0 != currentUserId }
            self.typingUsers = otherUsersTyping
            print("⌨️ Typing users: \(otherUsersTyping) (network: \(networkMonitor.isConnected))")
        }
    }
}
```

**Acceptance Criteria:**
- [ ] `updateTypingStatus()` checks both `isConnected` and `debugOfflineMode`
- [ ] Checks happen before Task and inside Task
- [ ] `subscribeToTyping()` checks both flags
- [ ] Logs include network state
- [ ] No compilation errors

**Testing:**
- Go offline and type
- Check logs for "double-check" message
- Verify no typing updates sent
- Rapid offline/online toggles
- Verify always correct

---

## Task 6: Clear Typing from Realtime DB When Going Offline
**Complexity:** 4
**Dependencies:** None
**File:** `messageAI/ViewModels/ChatViewModel.swift`

**Description:**
When the device goes offline, actively clear the user's typing status from Realtime Database. This prevents stuck typing indicators.

**Changes Required:**
- Function `setupNetworkOfflineListener()` around line 196-207
```swift
private func setupNetworkOfflineListener() {
    NotificationCenter.default.publisher(for: .networkDisconnected)
        .sink { [weak self] _ in
            guard let self = self else { return }
            
            // Clear typing indicators UI
            self.typingUsers = []
            print("📡 Offline: Cleared typing indicators UI")
            
            // Clear own typing status in Realtime DB
            if let conversationId = self.conversationId, let userId = self.currentUserId {
                Task {
                    await self.realtimeDBService.setTyping(
                        conversationId: conversationId,
                        userId: userId,
                        isTyping: false
                    )
                    print("📡 Offline: Cleared typing from Realtime DB")
                }
            }
        }
        .store(in: &cancellables)
}
```

**Acceptance Criteria:**
- [ ] Function clears typing from UI
- [ ] Function calls setTyping(false) to clear Realtime DB
- [ ] Logs both UI and DB clearing
- [ ] Uses stored conversationId and currentUserId
- [ ] No compilation errors

**Testing:**
- Start typing while online
- Go offline
- Check Realtime DB - typing should be false
- Other device shouldn't see typing

---

## Task 7: Verify FCM Token Registration
**Complexity:** 5
**Dependencies:** None
**Files:** `messageAI/Services/AuthService.swift`, `messageAI/Services/NotificationService.swift`

**Description:**
Ensure FCM tokens are properly registered for all users and stored in Firestore. Verify token registration happens on sign-in and token refresh.

**Investigation Required:**
- Check if FCM token is requested on app launch
- Check if token is stored in Firestore users/{userId}
- Verify token refresh is handled
- Add logging for token operations

**Changes Required:**
- If not present, add token registration after sign-in
- Add logging for token operations
- Verify token format and validity

**Acceptance Criteria:**
- [ ] FCM token requested on app launch
- [ ] Token stored in Firestore users collection
- [ ] Token refresh handled
- [ ] Comprehensive logging for token operations
- [ ] Token validated before storage

**Testing:**
- Launch app on simulator
- Check logs for FCM token
- Check Firestore users/{userId} for fcmToken field
- Verify token is valid format

---

## Task 8: Add Comprehensive Notification Logging
**Complexity:** 3
**Dependencies:** None
**File:** `messageAI/ViewModels/ConversationViewModel.swift`

**Description:**
Enhance existing notification logging to make debugging easier. Log every decision point and state check for notifications.

**Changes Required:**
- Function `setupMessageListeners()` around line 99-136
- Verify existing logs are comprehensive (already present but verify):
```swift
print("📬 Message received in conversation: \(conversation.id)")
print("   → Message ID: \(latestMessage.id)")
print("   → Sender: \(latestMessage.senderName)")
print("   → Text: \(latestMessage.previewText)")
print("   → App state: \(isInForeground ? "FOREGROUND" : "BACKGROUND")")
print("   → Current conversation: \(appStateService.currentConversationId ?? "none")")
print("   → This conversation: \(conversation.id)")
print("   → Viewing this conversation: \(isViewingConversation ? "YES" : "NO")")
print("   → Decision: \(shouldShowNotification ? "SHOW NOTIFICATION ✅" : "SKIP NOTIFICATION ❌")")
```

**Acceptance Criteria:**
- [ ] Logs message details
- [ ] Logs app state (foreground/background)
- [ ] Logs current conversation ID
- [ ] Logs whether viewing this conversation
- [ ] Logs notification decision
- [ ] Clear visual indicators (✅/❌)

**Testing:**
- Receive message
- Check logs for all information
- Verify logs help debug notification issues

---

## Task 9: Test Message Deletion End-to-End
**Complexity:** 6
**Dependencies:** Task 1, Task 2, Task 3
**Files:** Multiple (testing)

**Description:**
Comprehensive testing of message deletion across all scenarios using two simulators.

**Test Scenarios:**
1. **Delete middle message**: Delete message #3 out of 5
   - Verify no permission error
   - Verify message disappears from chat
   - Verify other device sees deletion
   - Verify chats list unchanged (not last message)

2. **Delete last message**: Delete most recent message
   - Verify no permission error
   - Verify message disappears from chat
   - Verify chats list updates immediately
   - Verify shows new last message
   - Verify other device sees both deletion and chats list update

3. **Delete all messages**: Delete all messages one by one
   - Verify each deletion succeeds
   - Verify chats list updates after each
   - Verify final deletion shows placeholder or empty state

4. **Try to delete other's message**: Swipe on message from other user
   - Verify delete option not shown OR
   - Verify error message appears

**Acceptance Criteria:**
- [ ] Can delete own messages without errors
- [ ] Cannot delete others' messages
- [ ] Chats list updates when last message deleted
- [ ] Both devices stay synchronized
- [ ] No permission errors in logs
- [ ] No stale data in any view

**Testing Process:**
- Use XcodeBuildMCP to build app
- Use ios-simulator MCP to launch 2 simulators
- Run through all 4 scenarios
- Document results with screenshots
- Check Firebase console for updated data

---

## Task 10: Test Offline Sync Timing
**Complexity:** 6
**Dependencies:** Task 4
**Files:** Multiple (testing)

**Description:**
Verify that sync triggers within 1 second of network reconnection and all pending messages upload successfully.

**Test Scenarios:**
1. **Single message sync**:
   - Go offline
   - Send 1 message
   - Go online
   - Measure time from "notification received" to "sync started"
   - Verify < 1 second

2. **Multiple messages sync**:
   - Go offline
   - Send 5 messages
   - Go online
   - Verify sync starts < 1 second
   - Verify all 5 messages upload

3. **Rapid offline/online toggles**:
   - Toggle offline/online 5 times quickly
   - Send message after each toggle
   - Verify all messages eventually sync
   - Verify no messages lost

4. **Real network reconnection** (if possible):
   - Disable WiFi on Mac
   - Send messages
   - Enable WiFi
   - Verify sync happens automatically

**Acceptance Criteria:**
- [ ] Sync starts within 1 second (measured)
- [ ] Logs show exact timing
- [ ] All pending messages upload successfully
- [ ] Works with rapid toggles
- [ ] No messages lost

**Testing Process:**
- Use simulators
- Check logs for timing data
- Parse logs to extract delays
- Verify all delays < 1 second
- Document worst-case timing

---

## Task 11: Test Typing Indicators Bulletproof Behavior
**Complexity:** 5
**Dependencies:** Task 5, Task 6
**Files:** Multiple (testing)

**Description:**
Test typing indicators in every possible offline/online scenario to verify 100% reliability.

**Test Scenarios:**
1. **Normal offline/online**:
   - Go offline, type → no typing sent
   - Other types → no typing displayed
   - Go online → typing works normally

2. **Rapid toggles**:
   - Offline → type → online → offline → type → online
   - Verify correct behavior at each step
   - No stuck typing indicators

3. **Type while going offline**:
   - Start typing online
   - Toggle offline WHILE typing
   - Verify typing clears immediately

4. **Receive typing while going offline**:
   - Other user typing online
   - Toggle offline
   - Verify typing indicator clears

5. **Edge cases**:
   - Multiple rapid toggles
   - Type during toggle
   - Check Realtime DB state

**Acceptance Criteria:**
- [ ] Never shows typing when offline (100%)
- [ ] Never sends typing when offline (100%)
- [ ] Clears typing when going offline
- [ ] Works with rapid toggles
- [ ] No stuck indicators
- [ ] Realtime DB stays clean

**Testing Process:**
- Use 2 simulators
- Run through all scenarios
- Check both client logs and Realtime DB
- Document any failures
- Verify 100% success rate

---

## Task 12: Test Notification Consistency
**Complexity:** 6
**Dependencies:** Task 7, Task 8
**Files:** Multiple (testing)

**Description:**
Test push notifications in all scenarios to verify 100% reliability.

**Test Scenarios:**
1. **Foreground - different conversation**:
   - Device A viewing Chat 1
   - Device B sends to Chat 2
   - Verify Device A shows notification
   - Repeat 5 times → 100% success rate

2. **Foreground - same conversation**:
   - Device A viewing Chat 1
   - Device B sends to Chat 1
   - Verify NO notification (user sees message)

3. **Foreground - different tab**:
   - Device A on Decisions tab
   - Device B sends message
   - Verify Device A shows notification

4. **Background**:
   - Device A in background
   - Device B sends message
   - Verify Device A shows system notification

5. **FCM token validation**:
   - Check Firestore for fcmToken on both users
   - Verify tokens are valid format
   - Check Firebase function logs

**Acceptance Criteria:**
- [ ] Foreground notifications: 100% success (when not viewing)
- [ ] Background notifications: 100% success
- [ ] No notifications when viewing conversation
- [ ] FCM tokens valid and registered
- [ ] Firebase function triggers every time

**Testing Process:**
- Use 2 simulators
- Repeat each scenario 5 times
- Document success rate
- Check Firebase console logs
- Verify 100% reliability

---

## Task 13: Verify View Synchronization
**Complexity:** 4
**Dependencies:** Task 9
**Files:** Multiple (testing)

**Description:**
Verify that all views (chats list, chat view, etc.) stay synchronized when data changes.

**Test Scenarios:**
1. **Send message**:
   - Send on Device B
   - Verify appears on Device A chat view
   - Verify appears on Device A chats list

2. **Delete message**:
   - Delete on Device B
   - Verify disappears on Device A chat view
   - Verify disappears on Device A chats list (if last message)

3. **Multiple rapid changes**:
   - Send, delete, send, delete rapidly
   - Verify both devices stay in sync
   - Verify no stale data

4. **Real-time updates**:
   - Measure time from change to update
   - Verify < 3 seconds

**Acceptance Criteria:**
- [ ] All views show same data
- [ ] Updates happen in real-time
- [ ] No stale data in any view
- [ ] Works with rapid changes
- [ ] Both devices always synchronized

**Testing Process:**
- Use 2 simulators
- Make changes on one
- Verify updates on other
- Measure timing
- Document any sync issues

---

## Implementation Order

Execute tasks in this exact order:

1. **Task 1** (Fix Security Rule) - Highest priority, unblocks deletion
2. **Task 2** (Add Update Function) - Needed for Task 3
3. **Task 3** (Update ChatViewModel) - Main deletion fix
4. **Task 9** (Test Deletion) - Verify Tasks 1-3 work
5. **Task 4** (Add Timing Logs) - Needed for sync verification
6. **Task 10** (Test Sync Timing) - Verify sync speed
7. **Task 5** (Double-Check Typing) - Typing reliability fix
8. **Task 6** (Clear Typing from DB) - Additional typing fix
9. **Task 11** (Test Typing) - Verify Tasks 5-6 work
10. **Task 7** (Verify FCM Tokens) - Notification prerequisite
11. **Task 8** (Add Notification Logs) - Better debugging
12. **Task 12** (Test Notifications) - Verify Tasks 7-8 work
13. **Task 13** (Verify Sync) - Final integration test

## Complexity Summary

- Task 1: Complexity 4 ✅ (< 7)
- Task 2: Complexity 3 ✅ (< 7)
- Task 3: Complexity 6 ✅ (< 7)
- Task 4: Complexity 3 ✅ (< 7)
- Task 5: Complexity 4 ✅ (< 7)
- Task 6: Complexity 4 ✅ (< 7)
- Task 7: Complexity 5 ✅ (< 7)
- Task 8: Complexity 3 ✅ (< 7)
- Task 9: Complexity 6 ✅ (< 7)
- Task 10: Complexity 6 ✅ (< 7)
- Task 11: Complexity 5 ✅ (< 7)
- Task 12: Complexity 6 ✅ (< 7)
- Task 13: Complexity 4 ✅ (< 7)

**All 13 tasks are under complexity 7 as required.**

## Files to Modify

1. `firestore.rules` - Delete permissions (Task 1)
2. `messageAI/Services/FirestoreService.swift` - Update lastMessage functions (Task 2)
3. `messageAI/ViewModels/ChatViewModel.swift` - Update after deletion, typing checks (Tasks 3, 5, 6)
4. `messageAI/Services/SyncService.swift` - Timing logs (Task 4)
5. `messageAI/Services/AuthService.swift` - FCM token (Task 7)
6. `messageAI/ViewModels/ConversationViewModel.swift` - Notification logs (Task 8)

**Total: 6 files**

## Success Metrics

After completing all tasks:

- ✅ Zero permission errors during deletion
- ✅ Chats list updates within 1 second of deletion
- ✅ Sync starts within 1 second of reconnection (measured)
- ✅ Typing indicators 100% reliable when offline
- ✅ Notifications 100% consistent
- ✅ All views always synchronized
- ✅ No data loss
- ✅ Clean build with no errors/warnings

