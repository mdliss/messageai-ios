# Offline Messaging and Typing Indicators Fix - Tasks

## Overview
Fix three critical bugs: typing indicators showing when offline, permission errors preventing message sync, and messages not reaching users after coming back online.

## Task Breakdown

### Task 1: Fix Firestore Security Rules for Conversation Updates
**Complexity:** 4
**Dependencies:** None
**File:** `firestore.rules`

**Description:**
Update the security rules for conversation documents to properly handle both create and update operations. The current rule only checks `resource.data.participantIds` which doesn't exist during create operations or certain update states, causing "Permission denied" errors during message sync.

**Changes Required:**
- Line 21-23: Replace single `allow read, write` rule with separate rules
- Add `allow read:` for read operations checking `resource.data.participantIds`
- Add `allow create:` for create operations checking `request.resource.data.participantIds`
- Add `allow update:` for update operations checking `resource.data.participantIds`

**Acceptance Criteria:**
- [ ] Security rule separates read, create, and update operations
- [ ] Create operations check `request.resource.data.participantIds`
- [ ] Update operations check `resource.data.participantIds`
- [ ] Rule allows authenticated participants to update conversation's lastMessage field
- [ ] No syntax errors in rules file

**Testing:**
- Deploy rules: `firebase deploy --only firestore:rules`
- Verify rules compile without errors
- Test update operation manually doesn't throw permission error

---

### Task 2: Add Offline Check to updateTypingStatus Function
**Complexity:** 2
**Dependencies:** None
**File:** `messageAI/ViewModels/ChatViewModel.swift`

**Description:**
Prevent sending typing indicator updates to Realtime Database when the device is offline. Currently the function always sends updates regardless of network state.

**Changes Required:**
- Function `updateTypingStatus(isTyping:currentUserId:)` at line 212
- After the `guard let conversationId` check, add:
  ```swift
  // Don't send typing updates if offline
  guard networkMonitor.isConnected else {
      print("⚠️ Offline: Not sending typing update")
      return
  }
  ```

**Acceptance Criteria:**
- [ ] Function checks `networkMonitor.isConnected` before sending typing update
- [ ] Returns early if offline without calling `setTyping()`
- [ ] Logs when typing update is skipped due to offline state
- [ ] Online typing updates still work normally

**Testing:**
- Toggle offline mode and type in chat
- Verify no typing update sent (check logs for warning message)
- Go online and type - verify typing update sent

---

### Task 3: Add Offline Check to subscribeToTyping Function
**Complexity:** 3
**Dependencies:** None
**File:** `messageAI/ViewModels/ChatViewModel.swift`

**Description:**
Prevent displaying typing indicators received from Realtime Database when the device is offline. An offline device shouldn't show what others are typing.

**Changes Required:**
- Function `subscribeToTyping(conversationId:currentUserId:)` at line 199
- Inside the `for await` loop, before filtering typing users:
  ```swift
  // Don't display typing indicators if offline
  guard networkMonitor.isConnected else {
      self.typingUsers = []
      print("⚠️ Offline: Not displaying typing indicators")
      continue
  }
  ```

**Acceptance Criteria:**
- [ ] Function checks `networkMonitor.isConnected` in the loop
- [ ] Clears `typingUsers` array when offline
- [ ] Continues loop without processing typing data
- [ ] Logs when typing indicators are ignored due to offline state
- [ ] Online devices still receive and display typing indicators normally

**Testing:**
- Open chat, see typing indicator working
- Toggle offline mode
- Verify typing indicator disappears
- Have other user type - verify no typing indicator shown

---

### Task 4: Add Network Disconnection Listener to Clear Typing Indicators
**Complexity:** 3
**Dependencies:** None
**File:** `messageAI/ViewModels/ChatViewModel.swift`

**Description:**
Automatically clear typing indicators when the device goes offline. This ensures immediate UI feedback when network state changes.

**Changes Required:**
- Add new function:
  ```swift
  /// Set up listener for network disconnection to clear typing indicators
  private func setupNetworkOfflineListener() {
      NotificationCenter.default.publisher(for: .networkDisconnected)
          .sink { [weak self] _ in
              guard let self = self else { return }
              
              // Clear typing indicators when going offline
              self.typingUsers = []
              print("📡 Offline: Cleared typing indicators")
          }
          .store(in: &cancellables)
  }
  ```
- Call this function in `loadMessages()` after `setupNetworkReconnectionListener()`

**Acceptance Criteria:**
- [ ] New function subscribes to `.networkDisconnected` notification
- [ ] Clears `typingUsers` array when notification received
- [ ] Logs when typing indicators cleared due to disconnect
- [ ] Function called during chat initialization
- [ ] Subscription added to `cancellables` for proper cleanup

**Testing:**
- Open chat with active typing indicator
- Toggle offline mode
- Verify typing indicator disappears immediately
- Check logs for "Offline: Cleared typing indicators" message

---

### Task 5: Test Typing Indicators with Offline Transitions
**Complexity:** 5
**Dependencies:** Task 2, Task 3, Task 4
**Files:** Multiple (testing)

**Description:**
Comprehensive testing of typing indicators across all offline/online state transitions on two simulators.

**Test Scenarios:**
1. **Baseline**: Both devices online, typing works
2. **Device A offline**: A types, B shouldn't see indicator
3. **Device A offline**: B types, A shouldn't see indicator  
4. **Device A online again**: Typing resumes working both ways
5. **Rapid offline/online**: Toggle multiple times, no stuck indicators
6. **Edge case**: Typing indicator active when going offline clears immediately

**Acceptance Criteria:**
- [ ] Typing indicators never show when sender is offline
- [ ] Typing indicators never show on offline device
- [ ] Going offline clears any active typing indicators
- [ ] Coming online resumes normal typing functionality
- [ ] No stuck or ghost typing indicators after any transition
- [ ] Logs show correct offline/online state changes

**Testing Process:**
- Use XcodeBuildMCP to build app
- Use ios-simulator MCP to launch 2 simulators
- Run through all 6 scenarios
- Document results with screenshots

---

### Task 6: Test Message Sync After Security Rule Fix
**Complexity:** 6
**Dependencies:** Task 1
**Files:** Multiple (testing)

**Description:**
Verify that messages created while offline successfully sync to Firestore when coming back online, with no permission errors.

**Test Scenarios:**
1. **Single message sync**: Offline → 1 message → online → verify sync
2. **Multiple messages**: Offline → 5 messages → online → all sync
3. **Large batch**: Offline → 15 messages → online → all sync in order
4. **Cross-device**: A offline sends 3, B online receives all 3 after A online
5. **Error recovery**: Check retry logic if temporary network issue

**Data to Verify:**
- Logs show: "🔄 Syncing X pending messages..."
- Logs show: "✅ Synced message: [messageId]" for each
- NO "Permission denied" errors in logs
- NO "Missing or insufficient permissions" errors
- Firebase console shows messages in correct conversation path
- Message status changes from "sending" → "sent"
- Other device receives all messages

**Acceptance Criteria:**
- [ ] Messages created offline have `isSynced = false` in Core Data
- [ ] Coming online triggers automatic sync
- [ ] All pending messages upload successfully
- [ ] Zero permission errors in app logs
- [ ] Zero permission errors in Firebase console
- [ ] Messages appear on other device within 2-3 seconds
- [ ] Messages in chronological order
- [ ] Can sync 15+ messages without issues

**Testing Process:**
- Use XcodeBuildMCP to build app
- Use ios-simulator MCP to launch 2 simulators
- Run through all 5 scenarios
- Check both app logs and Firebase console
- Document success/failure for each scenario

---

### Task 7: Test Complete Offline/Online Workflow
**Complexity:** 6
**Dependencies:** Task 1, Task 2, Task 3, Task 4
**Files:** Multiple (testing)

**Description:**
End-to-end testing of the complete offline messaging workflow combining typing indicators and message syncing.

**Complete Workflow Test:**
1. Both devices start online, conversation working normally
2. Device A toggles offline mode
3. Verify typing indicators stop working for Device A
4. Device A sends 3 messages while offline
5. Verify messages show "Not Delivered" or "Sending"
6. Device B shouldn't receive these messages yet
7. Device A toggles online mode
8. Verify typing indicators resume working
9. Verify all 3 messages sync automatically
10. Verify Device B receives all 3 messages
11. Verify messages in correct order with correct timestamps

**Back-and-Forth Test:**
1. Device A: offline → 2 messages → online (sync)
2. Device B: offline → 3 messages → online (sync)
3. Device A: offline → 1 message → online (sync)
4. Verify both devices have complete conversation history (6 total messages)
5. Verify no duplicates, no missing messages

**Acceptance Criteria:**
- [ ] Complete workflow executes without errors
- [ ] Typing indicators behave correctly at each step
- [ ] All messages sync successfully
- [ ] No permission errors at any point
- [ ] Both devices end with identical conversation history
- [ ] Message order is chronologically correct
- [ ] No data loss, no duplicates

**Testing Process:**
- Use XcodeBuildMCP to build app
- Use ios-simulator MCP to launch 2 simulators  
- Execute complete workflow test step-by-step
- Execute back-and-forth test
- Document with screenshots at each step
- Verify Core Data and Firestore match

---

### Task 8: Verify No Regression in Existing Functionality
**Complexity:** 4
**Dependencies:** Task 1, Task 2, Task 3, Task 4
**Files:** Multiple (testing)

**Description:**
Ensure that fixes didn't break any existing functionality. Test all normal online messaging features.

**Features to Test:**
1. **Normal messaging (online)**: Send messages, appear instantly
2. **Typing indicators (online)**: Work normally when both online
3. **Message status updates**: sending → sent → delivered → read
4. **Conversation list updates**: lastMessage updates correctly
5. **Real-time listeners**: New messages appear in real-time
6. **Image messages**: Still work if implemented
7. **Group chats**: Typing and messaging work with 3+ users
8. **App lifecycle**: Background/foreground transitions work
9. **User presence**: Online/offline status still works

**Acceptance Criteria:**
- [ ] All normal online messaging features work
- [ ] Typing indicators work when both users online
- [ ] Message delivery and read status work
- [ ] No build errors or warnings
- [ ] No new crashes or exceptions
- [ ] Performance is same or better
- [ ] UI/UX is unchanged for normal usage

**Testing Process:**
- Use XcodeBuildMCP to verify build succeeds
- Test each feature in list above
- Compare behavior to pre-fix version
- Document any unexpected changes

---

## Implementation Order

Execute tasks in this exact order:

1. **Task 1** (Fix Security Rules) - Highest priority, unblocks sync
2. **Task 2** (Stop Sending Typing When Offline) - Simple, independent
3. **Task 3** (Stop Displaying Typing When Offline) - Simple, independent  
4. **Task 4** (Clear Typing On Disconnect) - Simple, independent
5. **Task 5** (Test Typing Indicators) - Verify Tasks 2-4 work
6. **Task 6** (Test Message Sync) - Verify Task 1 works
7. **Task 7** (Test Complete Workflow) - Integration test
8. **Task 8** (Verify No Regression) - Final verification

## Complexity Summary

- Task 1: Complexity 4 ✅ (< 7)
- Task 2: Complexity 2 ✅ (< 7)
- Task 3: Complexity 3 ✅ (< 7)
- Task 4: Complexity 3 ✅ (< 7)
- Task 5: Complexity 5 ✅ (< 7)
- Task 6: Complexity 6 ✅ (< 7)
- Task 7: Complexity 6 ✅ (< 7)
- Task 8: Complexity 4 ✅ (< 7)

**All tasks are under complexity 7 as required.**

## Files to Modify

1. `firestore.rules` - Security rules fix (Task 1)
2. `messageAI/ViewModels/ChatViewModel.swift` - Typing indicator fixes (Tasks 2, 3, 4)

**Total: 2 files, ~25 lines of code**

## Files NOT to Modify

- `SyncService.swift` - Already correct
- `FirestoreService.swift` - Already correct
- `NetworkMonitor.swift` - Already correct
- `RealtimeDBService.swift` - Already correct
- Core Data models - Already correct

## Success Metrics

After completing all tasks:

- ✅ Zero typing indicators when offline
- ✅ Zero permission errors during sync
- ✅ 100% of offline messages sync successfully
- ✅ Messages delivered within 2-3 seconds of coming online
- ✅ Zero data loss
- ✅ Zero duplicate messages
- ✅ All existing features still work
- ✅ Clean build with no errors/warnings

