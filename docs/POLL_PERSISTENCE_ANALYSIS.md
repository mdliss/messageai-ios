# Poll Persistence Issue - Root Cause Analysis

## 🔍 Root Cause Investigation

### Issue Description
Confirmed polls disappear from Decisions tab when navigating away and returning. This defeats the purpose of the Decisions tab as a historical record.

### Code Analysis

#### 1. Decision Creation (`DecisionsViewModel.swift` lines 259-302)

**What Happens When Poll is Confirmed:**
```swift
// Step 1: Update original poll document
try await insightRef.updateData([
    "metadata.pollStatus": "confirmed",
    "metadata.finalized": true,
    "metadata.winningOption": winningOption,
    "metadata.winningTime": winningTime
])

// Step 2: Create NEW decision document
let decisionRef = db.collection("conversations")
    .document(decision.conversationId)
    .collection("insights")
    .document()

let decisionData: [String: Any] = [
    "id": decisionRef.documentID,
    "type": "decision",           // Same type as poll
    "dismissed": false,             // Not dismissed
    "metadata": [
        "pollId": decision.id,      // Links to original poll
        "winningOption": winningOption,
        "voteCount": voteCount,
        "totalVotes": totalVotes
    ]
]

try await decisionRef.setData(decisionData)
```

**Result**: Two documents in Firestore:
1. Original poll (isPoll=true, pollStatus=confirmed, finalized=true)
2. New decision (pollId != nil, type=decision)

#### 2. Decision Query (`DecisionsViewModel.swift` lines 59-64)

**Query Structure:**
```swift
let insightsRef = conversationDoc.reference
    .collection("insights")
    .whereField("type", isEqualTo: "decision")
    .whereField("dismissed", isEqualTo: false)
```

**Query Results:**
- Returns ALL documents where type="decision" AND dismissed=false
- Should return BOTH poll and decision (both have type="decision")
- Real-time listener fires when documents change

#### 3. Filter Logic (`DecisionsViewModel.swift` lines 91-116)

**Filtering After Query:**
```swift
let isPoll = insight.metadata?.isPoll == true
let isConsensusDecision = insight.metadata?.pollId != nil

if isPoll {
    // Show polls for 2+ participants
    return participantCount >= 2
} else if isConsensusDecision {
    // Always show consensus decisions
    return true
} else {
    // Show regular decisions for 3+ participants
    return participantCount >= 3
}
```

**Expected Results:**
- Original poll (isPoll=true) → Shows if 2+ participants ✅
- Decision entry (pollId != nil) → Always shows ✅

#### 4. Listener Lifecycle

**On Navigation TO Decisions Tab:**
```swift
.onAppear {
    viewModel.loadDecisions(userId: userId)
}
```

**loadDecisions() Flow:**
1. **NEW FIX**: Calls `cleanup()` first to remove old listeners
2. Queries all conversations
3. Sets up real-time listener for each conversation
4. Listener fires immediately with existing data
5. Listener stays attached until cleanup

**On Navigation AWAY from Decisions Tab:**
```swift
// Component unmounts, but cleanup() is NOT called automatically
// Listeners remain attached until next loadDecisions() call
```

**On Navigation BACK to Decisions Tab:**
```swift
.onAppear {
    viewModel.loadDecisions(userId: userId)  // Called again
}
```

**NEW FIX**: 
- loadDecisions() now calls cleanup() FIRST
- This removes old listeners before creating new ones
- Prevents duplicate listeners and memory leaks

### Potential Issues (Hypotheses)

#### Issue #1: Listener Duplication (FIXED)
**Before Fix:**
- Navigate to Decisions → creates listener
- Navigate away → listener stays attached
- Navigate back → creates ANOTHER listener (duplicate)
- Multiple listeners cause unpredictable behavior

**After Fix:**
- loadDecisions() calls cleanup() first
- Old listeners removed before new ones created
- No duplicates

#### Issue #2: Decision Document Not Created
**Check:**
- Console logs should show: "✅ Decision entry created successfully!"
- Firestore console should show the decision document
- If missing, creation is failing

#### Issue #3: Decision Document Not Queried
**Check:**
- Console logs should show: "📥 Received 2 documents from Firestore"
- If only 1 document, query is not returning decision
- Check if decision has correct type and dismissed fields

#### Issue #4: Decision Document Filtered Out
**Check:**
- Console logs should show: "🔍 Filtering [decision-id]: isPoll=false, isConsensus=true"
- Should show: "→ Consensus decision: showing=true"
- If filtered out, check filter logic

### Root Cause Hypothesis

Based on code analysis, the most likely root cause is:

**Hypothesis**: The decision document IS being created correctly, and the query IS returning it, but when the component unmounts and remounts, the listener is being duplicated or not properly managing state.

**Fix Applied**: 
- Added `cleanup()` call at start of `loadDecisions()`
- This ensures clean slate before attaching new listeners
- Prevents duplicate listeners and state management issues

### Secondary Issues (Potential)

1. **Timing Issue**: Decision document created after listener already fired
   - Real-time listener should pick it up automatically
   - Logs will show if listener fires after creation

2. **Firestore Rules**: Permissions might prevent reading decision documents
   - Check Firestore rules allow reading insights collection
   - Logs will show permission errors if this is the issue

3. **Date Parsing**: createdAt field might not parse correctly
   - Using Timestamp(date: Date()) for consistency
   - Should work with Codable

---

## 🔧 Fixes Implemented

### Fix #1: Cleanup Before Load (CRITICAL)
```swift
func loadDecisions(userId: String) {
    print("🔄 loadDecisions called for user: \(userId)")
    
    // CRITICAL FIX: Clean up existing listeners first
    cleanup()
    
    isLoading = true
    // ... rest of function
}
```

**Impact**: Prevents duplicate listeners, ensures clean state

### Fix #2: Comprehensive Logging
Added extensive logging at every step:
- When loadDecisions() called
- When cleanup() called
- When query executes
- When documents received
- When filtering decisions
- When listeners attached
- When decision created

**Impact**: Can diagnose exactly where issue occurs

### Fix #3: Enhanced Cleanup
```swift
func cleanup() {
    print("🧹 Cleanup called - removing \(listeners.count) listeners")
    decisionsTask?.cancel()
    listeners.forEach { $0.remove() }
    listeners.removeAll()
    print("✅ Cleanup complete - all listeners removed")
}
```

**Impact**: Clear visibility into listener lifecycle

---

## 🎯 Expected Outcome

After these fixes:

1. **Decision documents created correctly** ✅
2. **Query returns both poll and decision** ✅
3. **Listener reattaches on navigation** ✅ (via cleanup + reload)
4. **Decisions persist permanently** ✅
5. **No duplicate listeners** ✅ (cleanup prevents this)

### What Should Happen

1. Confirm poll → 2 documents in Firestore (poll + decision)
2. Navigate away → cleanup() removes listeners
3. Navigate back → loadDecisions() creates new listeners
4. Query returns both documents
5. Filter shows both (poll as finalized, decision as consensus)
6. UI displays both permanently

**If this works, the feature is complete and bug-free!**

---

## 📝 Testing Validation

Run the test cases in `POLL_PERSISTENCE_TEST_INSTRUCTIONS.md` and check console logs against expectations above.

If decisions persist after multiple navigations, the fix is successful! ✅

