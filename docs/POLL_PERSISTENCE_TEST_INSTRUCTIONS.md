# Poll Persistence Testing Instructions

## ✅ Setup Complete

**3 Simulators Running with Log Capture:**

### Simulator 1: iPhone 17 Pro
- UUID: `392624E5-102C-4F6D-B6B1-BC51F0CF7E63`
- Log Session: `5bd633b3-a5cd-4172-9338-5965b6ca9757`
- User: Test2
- Role: **Poll Creator (User A)**

### Simulator 2: iPhone 17 Pro Max  
- UUID: `70E288A9-A077-43D6-89E5-3FEC66839A34`
- Log Session: `c678f39f-4bb6-4b73-a2a2-eec32d25269d`
- User: Test3
- Role: **Participant (User B)**

### Simulator 3: iPhone 17
- UUID: `9AC3CA11-90B5-4883-92EA-E8EA0E3E0A56`
- Log Session: `36043334-387c-4201-938f-3486a17fbc96`
- User: Test (or Test2/Test3 depending on conversation)
- Role: **Participant (User C)**

---

## 🧪 Test Case 1: Basic Poll Confirmation and Persistence

### Step-by-Step Instructions

**Phase 1: Create Poll**
1. On Simulator 1 (User A - Poll Creator):
   - Navigate to an existing group chat OR create new group with all 3 users
   - Type message: "When can we meet?"
   - Wait for AI suggestion card to appear
   - Click "yes, help me" button
   - AI creates poll and posts in chat

2. On ALL 3 Simulators:
   - Navigate to **Decisions** tab (bottom navigation)
   - Verify poll appears with 3 time options
   - Look for console logs showing poll creation

**Phase 2: Cast Votes**
3. On Simulator 1 (User A):
   - In Decisions tab, tap any time option (e.g., Option 1)
   - Verify orange checkmark appears
   - Verify vote count badge shows "1"

4. On Simulator 2 (User B):
   - In Decisions tab, tap any time option (e.g., Option 1)
   - Verify vote count updates to "2"

5. On Simulator 3 (User C):
   - In Decisions tab, tap any time option (e.g., Option 2)
   - Verify vote counts update

**Phase 3: Verify Button Visibility**
6. On Simulator 1 (Poll Creator):
   - ✅ Should see GREEN "Confirm Decision" button
   - ✅ Should see RED "Cancel Poll" button
   - ✅ Buttons should be enabled and clickable

7. On Simulators 2 & 3 (Participants):
   - ❌ Should NOT see any buttons
   - ✅ Should see "waiting for creator to confirm..." message

**Phase 4: Confirm Poll**
8. On Simulator 1 (Poll Creator):
   - Click "Confirm Decision" button
   - Watch for loading spinner
   - Wait for confirmation to complete

9. On ALL 3 Simulators:
   - Verify poll updates to "confirmed" with green checkmark
   - Verify winning option has 🏆 badge or special styling
   - Verify system message appears in chat
   - Verify decision entry visible in Decisions tab

**Phase 5: TEST PERSISTENCE - Navigate Away and Back**
10. On ALL 3 Simulators:
    - Navigate to **Chats** tab (bottom navigation)
    - Wait 3 seconds
    - Navigate back to **Decisions** tab
    - **CRITICAL**: Verify confirmed decision is STILL VISIBLE
    - If it disappeared, the bug is NOT fixed

11. Repeat navigation 3 more times:
    - Decisions → Chats → Decisions (repeat 3x)
    - Decision should persist every single time

**Phase 6: TEST PERSISTENCE - App Navigation**
12. On ALL 3 Simulators:
    - Navigate to Profile tab
    - Navigate to AI tab
    - Navigate back to Decisions tab
    - **CRITICAL**: Verified confirmed decision is STILL VISIBLE

**Phase 7: Check Console Logs**
13. Stop log capture and examine logs for all 3 simulators
    - Look for decision creation messages
    - Look for listener attachment messages
    - Look for query results
    - Identify any errors or warnings

---

## 🔍 What to Look For in Console Logs

### When Decisions Tab Opens
```
🔄 loadDecisions called for user: [userId]
📊 Current listeners count: 0
📊 Current decisions count: 0
🧹 Cleanup called - removing 0 listeners
✅ Cleanup complete - all listeners removed
✅ Found 2 conversations for user
📝 Setting up listener for conversation: [conversationId]
   Conversation type: group, participants: 3
   Query: conversations/[conversationId]/insights where type='decision' and dismissed=false
📥 Received 2 documents from Firestore for conversation [conversationId]
   📄 Document [poll-id]: isPoll=true, pollId=nil, pollStatus=confirmed
   📄 Document [decision-id]: isPoll=false, pollId=[poll-id], pollStatus=unknown
   🔍 Filtering [poll-id]: isPoll=true, isConsensus=false, pollStatus=confirmed
      → Poll: showing=true (participants: 3)
   🔍 Filtering [decision-id]: isPoll=false, isConsensus=true, pollStatus=unknown
      → Consensus decision: showing=true (always show)
✅ After filtering: 2 insights to display
🔄 Removed 0 old insights, adding 2 new insights
📊 Total decisions now: 2
✅ Listener attached for conversation [conversationId]
```

### When Poll is Confirmed
```
🎯 confirming poll [poll-id] for user [userId]
📊 winning option: option_1 with 2 votes
⏰ winning time: thursday 12pm EST / 9am PST / 5pm GMT / 10:30pm IST
✅ poll confirmed successfully
📝 Poll document path: conversations/[conversationId]/insights/[poll-id]
📊 Creating decision document:
   Decision ID: [new-decision-id]
   Path: conversations/[conversationId]/insights/[new-decision-id]
   Type: decision
   Poll ID: [poll-id]
   Winning option: option_1
   Vote count: 2 of 3
   Consensus: false
📤 Writing decision document to Firestore...
✅ Decision entry created successfully!
   Document ID: [new-decision-id]
   This decision should now appear in Decisions tab for all participants
   Real-time listener will pick it up automatically
✅ system message posted
```

### When Navigating Away
```
🧹 Cleanup called - removing 1 listeners
✅ Cleanup complete - all listeners removed
```

### When Navigating Back
```
🔄 loadDecisions called for user: [userId]
📊 Current listeners count: 0
📊 Current decisions count: 2
🧹 Cleanup called - removing 0 listeners
[... query logs same as above ...]
📥 Received 2 documents from Firestore
✅ After filtering: 2 insights to display
📊 Total decisions now: 2
```

---

## 🚨 Red Flags to Watch For

### Bug NOT Fixed - Decision Disappears
```
📥 Received 1 documents from Firestore  ← ONLY 1 DOCUMENT!
📄 Document [poll-id]: isPoll=true, pollId=nil, pollStatus=confirmed
✅ After filtering: 1 insights to display  ← DECISION MISSING!
📊 Total decisions now: 1  ← ONLY POLL, NO DECISION
```

**This means**: Decision document was not created or query didn't return it

### Bug NOT Fixed - Listener Not Reattaching
```
🔄 loadDecisions called for user: [userId]
📊 Current listeners count: 1  ← OLD LISTENER STILL ATTACHED
[No new listener setup logs]
```

**This means**: Cleanup didn't work, old listeners persist

### Bug NOT Fixed - Decision Document Missing
```
✅ Decision entry created successfully!
[Later...]
📥 Received 1 documents from Firestore  ← Decision not in query results
```

**This means**: Decision was created but query doesn't return it

---

## 📊 Expected Test Results

### ✅ Success Criteria

After confirming a poll and navigating away/back multiple times:

**Decisions Tab Should Show:**
1. **Original Poll** (with isPoll=true, pollStatus=confirmed, finalized=true)
   - Displays with green checkmark header: "meeting scheduled ✓"
   - Shows all time options with vote counts
   - Shows winning option with special styling
   - Shows "final decision: [winning time]" banner

2. **Decision Entry** (with pollId != nil, type=decision)
   - Displays as regular decision
   - Shows "consensus reached" if all voted same
   - Shows vote count (X of Y voted)
   - Shows timestamp

**Total visible items**: 2 (poll + decision) OR just 1 if we decide to hide confirmed polls

### 🎯 Specific Checks

- [ ] Decisions tab shows content after first navigation
- [ ] Content persists after navigating to Chats and back
- [ ] Content persists after navigating to Profile and back
- [ ] Content persists after navigating to AI tab and back
- [ ] Content persists after 5 navigation cycles
- [ ] Console logs show "Total decisions now: 2" (or at least 1)
- [ ] Console logs show decision document being created
- [ ] Console logs show query returning the decision document
- [ ] No errors in console logs
- [ ] Real-time listener picks up new decision automatically

---

## 📸 Screenshots to Capture

### Screenshot 1: Poll Creator View - Active Poll
- Before confirmation
- Shows Confirm/Cancel buttons
- Shows vote counts

### Screenshot 2: Participant View - Active Poll
- Before confirmation  
- Shows "waiting for creator" message
- NO buttons visible

### Screenshot 3: All Users - After Confirmation
- After poll confirmed
- Shows confirmed decision
- Shows winning option

### Screenshot 4: Persistence Test - After Navigation
- Navigate away and back to Decisions tab
- Decision still visible
- Proves persistence works

### Screenshot 5: Multiple Navigations
- After 5 navigation cycles
- Decision still visible
- Timestamp unchanged

---

## 🐛 If Decision Disappears (Bug Not Fixed)

### Debugging Steps

1. **Check Console Logs**:
   - Look for decision creation log with document ID
   - Note the decision ID
   - Look for query results after navigation
   - Check if decision ID appears in query results
   - If missing from query, there's a query/filter issue

2. **Check Firestore Console** (manually):
   - Open Firebase console
   - Navigate to Firestore
   - Go to conversations → [conversationId] → insights
   - Look for the decision document created
   - Verify it exists with correct fields
   - If exists but not showing, it's a query problem
   - If doesn't exist, it's a creation problem

3. **Verify Decision Document Structure**:
   Look for decision with these exact fields:
   - `type: "decision"` ← MUST be exactly this
   - `dismissed: false` ← MUST be false
   - `metadata.pollId: "[poll-id]"` ← Must reference original poll
   - `conversationId: "[conversation-id]"` ← Must match conversation

4. **Check Filter Logic**:
   In console logs, look for:
   ```
   🔍 Filtering [decision-id]: isPoll=false, isConsensus=true, pollStatus=unknown
      → Consensus decision: showing=true (always show)
   ```
   If this doesn't appear, decision is being filtered out

5. **Check Listener Lifecycle**:
   ```
   Navigate to Decisions:
   🔄 loadDecisions called
   🧹 Cleanup called - removing X listeners
   📝 Setting up listener...
   ✅ Listener attached
   
   Navigate away:
   🧹 Cleanup called - removing 1 listeners
   ✅ Cleanup complete
   
   Navigate back:
   🔄 loadDecisions called  ← Should happen!
   [Repeat setup logs]
   ```

---

## 🔧 Next Steps Based on Test Results

### If Persistence Works ✅
- Decision persists after navigation
- Console logs show decision document created and queried
- All 3 simulators see the decision
- **Action**: Mark feature complete, deploy to production

### If Persistence Fails ❌
- Decision disappears after navigation
- Console logs reveal the issue
- **Action**: Based on logs, implement specific fix:
  - If decision not created: Fix creation logic
  - If decision not queried: Fix query filter
  - If listener not reattaching: Fix lifecycle management

---

## 📝 Test Results Form

Fill this out after testing:

**Test Date**: [DATE]
**Tester**: [YOUR NAME]
**Build**: Debug-iphonesimulator with comprehensive logging

### Basic Confirmation
- Poll created successfully: [ YES / NO ]
- Buttons visible to creator only: [ YES / NO ]
- Participants see "waiting" message: [ YES / NO ]
- Poll confirmed successfully: [ YES / NO ]
- System message posted: [ YES / NO ]

### Persistence After Navigation
- Decision visible initially: [ YES / NO ]
- Persists after nav to Chats: [ YES / NO ]
- Persists after nav to Profile: [ YES / NO ]
- Persists after nav to AI: [ YES / NO ]
- Persists after 5 nav cycles: [ YES / NO ]

### Console Log Analysis
- Decision creation logged: [ YES / NO ]
- Decision ID: [WRITE ID HERE]
- Query returns decision: [ YES / NO ]
- Listener reattaches properly: [ YES / NO ]
- Total decisions shown: [NUMBER]

### Overall Result
- Feature works correctly: [ PASS / FAIL ]
- Decisions persist permanently: [ PASS / FAIL ]

---

## 🎬 Ready to Test!

**Your 3 simulators are running and ready.** Follow the instructions above to test poll persistence. The extensive logging will help us diagnose any issues.

After testing, I can analyze the logs to see exactly what's happening and fix any remaining issues.

