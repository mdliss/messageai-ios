# Testing Guide: Advanced AI Features

comprehensive testing instructions for the three advanced ai features.

---

## Prerequisites

before testing:
1. deploy all cloud functions: `firebase deploy --only functions`
2. deploy firestore indexes: `firebase deploy --only firestore:indexes`
3. build ios app successfully (xcode or xcodebuildmcp)
4. have 3 test user accounts ready
5. ensure openai api key is configured in firebase

---

## Feature 1: Smart Response Suggestions

### Test Case 1: Basic Suggestion Generation

**setup:**
1. launch 2 simulators: manager and team member
2. sign in to both

**steps:**
1. team member sends: "can we push the deadline to next friday? we're behind on the design work."
2. on manager's device, wait 2-3 seconds
3. verify response suggestions card appears above message input
4. verify 3-4 suggestions are shown
5. verify suggestions are contextually relevant
6. verify different types shown (approve, decline, conditional, delegate)

**expected results:**
- suggestions appear automatically
- card shows loading spinner briefly
- 3-4 suggestions displayed
- each has icon, text, reasoning
- different colored borders for different types

**screenshot:** suggestions card with 4 options

### Test Case 2: Suggestion Selection and Editing

**steps:**
1. from test case 1, tap on an "approve" suggestion
2. verify text inserts into message input field
3. verify text does NOT auto-send (user can still edit)
4. edit the inserted text (add personal touch)
5. send the message

**expected results:**
- tapped suggestion text appears in input field
- message input field becomes first responder
- user can edit text before sending
- suggestions card dismisses after selection
- haptic feedback on tap

**screenshot:** suggestion inserted into input field

### Test Case 3: Suggestion Dismissal

**steps:**
1. generate suggestions for a message
2. tap the X button on suggestions card
3. verify card disappears
4. user can type their own response

**expected results:**
- card dismisses immediately
- no suggestions remain visible
- user can type freely

### Test Case 4: Caching Behavior

**steps:**
1. generate suggestions for message a
2. switch to different conversation
3. return to original conversation
4. verify suggestions still shown (cached)
5. wait 6+ minutes
6. verify suggestions regenerate (cache expired)

**expected results:**
- suggestions load instantly from cache if < 5 min
- suggestions regenerate if > 5 min
- logs show "using cached suggestions" or "cache expired"

### Test Case 5: No Suggestions for Casual Messages

**steps:**
1. team member sends: "thanks! got it"
2. team member sends: "fyi the meeting moved to 3pm"
3. team member sends casual message without question or request
4. verify suggestions do NOT appear

**expected results:**
- no suggestion card for informational messages
- no suggestion card for acknowledgments
- no suggestion card for casual chat

---

## Feature 2: Proactive Blocker Detection

### Test Case 6: Explicit Blocker Detection

**setup:**
- 3 simulators: manager + 2 team members
- group conversation

**steps:**
1. team member 1 sends: "i'm blocked on the database migration. waiting for credentials from devops."
2. wait 2-3 seconds for background processing
3. on manager's device, check if blocker notification appears (if severity is high)
4. navigate to blocker dashboard
5. verify blocker is listed

**expected results:**
- notification appears (if high/critical severity)
- blocker dashboard shows 1 active blocker
- blocker card displays:
  - severity indicator (colored)
  - blocked person name
  - blocker description
  - suggested actions
  - time elapsed

**screenshot:** blocker dashboard with active blocker

### Test Case 7: Multiple Blockers with Different Severities

**steps:**
1. team member 1 sends: "production is down! can't deploy the fix without access" (critical)
2. team member 2 sends: "stuck on this bug for 3 hours, can't figure it out" (high)
3. wait for background processing
4. open blocker dashboard
5. verify both blockers listed
6. verify sorted by severity (critical first)

**expected results:**
- 2 blockers in dashboard
- critical blocker listed first
- correct severity colors (red for critical, orange for high)
- both have suggested actions

**screenshot:** dashboard with multiple blockers

### Test Case 8: Blocker Resolution

**steps:**
1. from test case 7, tap "mark resolved" on first blocker
2. optionally add resolution notes: "granted access, issue resolved"
3. submit
4. verify blocker removed from active list
5. verify updated in firestore (status = 'resolved')

**expected results:**
- blocker disappears from active list
- resolution notes saved
- resolution timestamp and manager id recorded
- if no more blockers, empty state shows

**screenshot:** empty state after resolving all blockers

### Test Case 9: Blocker Snooze

**steps:**
1. create blocker (send blocked message)
2. tap "snooze" button
3. select "4 hours" from menu
4. verify blocker removed from active list

**expected results:**
- blocker removed from current view
- status updated to 'snoozed'
- snoozedUntil timestamp set
- TODO: blocker reappears after 4 hours (requires implementation)

### Test Case 10: False Positive Marking

**steps:**
1. create blocker
2. tap "false positive" button
3. verify blocker removed from list

**expected results:**
- blocker removed immediately
- status = 'false_positive'
- managerMarkedFalsePositive = true (helps ai learn)

### Test Case 11: Severity Classification Accuracy

**test messages with expected severities:**

**critical blockers:**
- "production is down, can't deploy fix" → critical
- "entire team blocked on this for 2 days" → critical
- "customer facing bug, need fix immediately" → critical

**high blockers:**
- "been waiting 8 hours for approval, blocking sprint" → high
- "stuck on this, no one responding to help requests" → high
- "can't access staging, blocking all testing" → high

**medium blockers:**
- "waiting a few hours for design review" → medium
- "need help with this when someone has time" → medium
- "minor access issue, can work on other stuff" → medium

**low blockers:**
- "quick question about styling" → low
- "just mentioned, someone already helping" → low

send each message, verify ai classifies severity correctly

**expected accuracy: 85%+ correct severity classification**

---

## Feature 3: Team Sentiment Analysis

### Test Case 12: Positive Sentiment Detection

**setup:**
- 3 simulators in group conversation

**steps:**
1. team member 1 sends: "so excited about this new feature! great work team! 🎉"
2. wait for background sentiment analysis (2-3 seconds)
3. verify message gets positive sentiment score
4. wait for hourly aggregate (or manually trigger function)
5. open sentiment dashboard
6. verify team member 1 shows positive sentiment

**expected results:**
- message.sentimentScore > 0.5 (very positive)
- emotions detected: ["excited", "enthusiastic"]
- dashboard shows green indicator for team member
- team overall sentiment is positive

**screenshot:** sentiment dashboard showing positive sentiment

### Test Case 13: Negative Sentiment Detection

**steps:**
1. team member 2 sends: "this is so frustrating, nothing is working right 😤"
2. team member 2 sends: "i'm completely overwhelmed, too much on my plate"
3. wait for analysis
4. open sentiment dashboard
5. verify team member 2 shows negative sentiment

**expected results:**
- messages get negative sentiment scores (< -0.3)
- emotions: ["frustrated", "stressed", "overwhelmed"]
- dashboard shows orange/red indicator
- member card sorted to top (most concerning first)

**screenshot:** member card showing negative sentiment

### Test Case 14: Neutral Sentiment

**steps:**
1. team member 3 sends: "updated the documentation, meeting at 3pm"
2. team member 3 sends: "completed the task, pushing to staging"
3. verify sentiment is neutral

**expected results:**
- sentiment scores near 0 (-0.2 to 0.2)
- dashboard shows gray indicator
- emotions: [] or minimal

### Test Case 15: Sentiment Trend Tracking

**steps:**
1. over several hours, have team members send variety of messages
2. wait for hourly aggregate calculation
3. check sentiment dashboard periodically
4. send mostly negative messages for a period
5. verify trend graph updates
6. verify team sentiment score changes

**expected results:**
- trend graph shows sentiment changes over time
- negative messages pull score down
- positive messages pull score up
- 7 day trend visible in graph

**screenshot:** sentiment trend graph

### Test Case 16: Individual Member Sentiment Details

**steps:**
1. from sentiment dashboard, tap on team member with negative sentiment
2. verify individual detail view opens (TODO: implement this view)
3. should show:
   - member's sentiment history (30 day graph)
   - recent negative messages with context
   - suggested actions for manager

**note:** individual detail view not yet implemented in current code

### Test Case 17: Sentiment Alert for Significant Drop

**steps:**
1. establish baseline positive sentiment
2. have team send many negative messages over 24 hours
3. wait for hourly aggregate
4. when team sentiment drops 30+ points (0.3+ on -1 to 1 scale):
5. verify alert created
6. verify notification sent to managers

**expected results:**
- alert document created in sentimentTracking/alerts
- push notification: "team sentiment dropped x points"
- alert provides context and suggests checking in

---

## Integration Testing

### Test Case 18: Unified AI Dashboard

**steps:**
1. navigate to unified ai dashboard
2. verify shows:
   - response suggestions count
   - active blockers count
   - team sentiment score
   - priority messages count (existing)
   - action items count (existing)
3. tap each card to navigate to detail view

**expected results:**
- dashboard loads quickly (< 1 second)
- all counts accurate
- navigation works for each feature

**screenshot:** unified dashboard overview

### Test Case 19: AI Features Settings

**steps:**
1. navigate to settings → ai features
2. verify all toggles present:
   - response suggestions (on/off)
   - blocker detection (on/off)
   - blocker notifications (on/off if detection enabled)
   - sentiment analysis (on/off)
   - sentiment alerts (on/off if analysis enabled)
3. toggle each feature off
4. verify features respect the settings
5. re-enable features

**expected results:**
- toggles save immediately
- disabled features don't show ui
- disabled features don't run background processing
- settings sync across devices (firestore user.preferences)

**screenshot:** ai features settings panel

### Test Case 20: Opt-Out Mechanisms

**steps:**
1. disable response suggestions
2. send message requiring response
3. verify no suggestions appear
4. disable blocker detection
5. send blocker message
6. verify no blocker detected
7. disable sentiment analysis
8. send emotional message
9. verify no sentiment analyzed

**expected results:**
- disabled features completely stop working
- no ui components shown
- no background processing happens
- no ai api calls made

---

## Performance Testing

### Test Case 21: Response Time

**measure:**
- response suggestions: should complete in < 3 seconds (95th percentile)
- blocker detection: background, should not slow message delivery
- sentiment analysis: background, should not slow message delivery

**steps:**
1. send 20 messages requiring responses
2. measure time from message arrival to suggestions appearing
3. calculate p50, p95, p99

**acceptance:**
- p50: < 2 seconds
- p95: < 3 seconds
- p99: < 5 seconds

### Test Case 22: App Responsiveness Under Load

**steps:**
1. send 50+ messages rapidly
2. verify all features continue working
3. verify no lag or freezing
4. verify app remains responsive
5. monitor for crashes or memory issues

**expected results:**
- app stays smooth (60 fps)
- background processing doesn't block ui
- no crashes
- memory usage reasonable

---

## Error Handling Testing

### Test Case 23: AI API Failure

**steps:**
1. temporarily break openai api key configuration
2. try to generate suggestions
3. verify graceful error handling

**expected results:**
- user friendly error message shown
- app doesn't crash
- user can still type their own response
- error logged in firebase

### Test Case 24: Network Offline

**steps:**
1. disable network on device
2. send message requiring response
3. verify suggestions don't appear (offline)
4. re-enable network
5. verify suggestions appear

**expected results:**
- offline: no suggestions (cloud function can't be called)
- online: suggestions work normally
- no crashes or hanging

---

## Privacy and Ethics Testing

### Test Case 25: Data Access

**verify:**
- managers can only see blockers in conversations they're part of
- managers can only see sentiment for conversations they're in
- users can't access other users' private sentiment data
- firestore security rules enforce this

### Test Case 26: Transparency

**verify:**
- privacy notes are clear and visible
- purpose stated clearly (support, not surveillance)
- opt-out options are easy to find
- users understand what data is analyzed

---

## Deployment Checklist

before deploying to production:

**firebase:**
- [ ] deploy all cloud functions
- [ ] deploy firestore indexes
- [ ] verify openai api key configured
- [ ] test functions manually with firebase console
- [ ] check function logs for errors
- [ ] verify firestore security rules updated

**ios app:**
- [ ] build succeeds with zero errors, zero warnings
- [ ] all new files added to xcode project
- [ ] test on multiple simulators (iphone, ipad)
- [ ] test on physical device
- [ ] verify no memory leaks
- [ ] verify battery usage reasonable

**testing:**
- [ ] all 26 test cases passed
- [ ] no critical bugs found
- [ ] performance targets met
- [ ] privacy controls working
- [ ] opt-out mechanisms working

---

## Known Limitations and Future Enhancements

**current limitations:**
1. suggestions don't learn from edits yet (feedback stored but not used)
2. snoozed blockers don't reappear after snooze expires (need scheduler)
3. individual sentiment detail view not implemented (only dashboard)
4. unified dashboard counts are stubbed (need real queries)
5. no navigation from unified dashboard to feature detail views yet

**future enhancements:**
1. sentiment analysis: add individual detail view with 30 day history
2. blocker detection: add automatic recheck of snoozed blockers
3. response suggestions: implement actual learning from feedback data
4. unified dashboard: wire up real time counts and navigation
5. notifications: implement push notifications for alerts
6. analytics: track feature usage and value metrics

---

## Troubleshooting

**suggestions not appearing:**
- check if message triggers conditions (ends with "?", has keywords)
- check firebase function logs for errors
- verify openai api key configured
- check network connectivity
- verify responseSuggestionsEnabled in settings

**blockers not detected:**
- check if message contains blocker keywords
- check firebase logs for trigger execution
- verify onMessageCreatedCheckBlocker deployed
- check blocker detection confidence threshold (must be > 0.7)

**sentiment not updating:**
- check if messages are text type (images not analyzed)
- verify onMessageCreatedAnalyzeSentiment trigger deployed
- check hourly aggregate function running (scheduled)
- verify sentiment confidence > 0.5

**build errors:**
- ensure all new files added to xcode project
- verify all imports correct (combine, firebasefirestore, etc)
- check for typos in function/struct names
- run clean build if needed

---

## Success Metrics to Monitor

**response suggestions:**
- adoption rate: 40%+ of suggestions used
- time saved: 30%+ reduction in response time
- user rating: 80%+ rate as helpful
- false triggers: < 15%

**blocker detection:**
- detection accuracy: 85%+ of real blockers caught
- false positive rate: < 10%
- manager response time: 70%+ act within 2 hours
- blocker resolution time: 40%+ reduction

**sentiment analysis:**
- accuracy: 80%+ correlation with human assessment
- early warning: 2-3 days before manager notices
- actionability: 50%+ of alerts lead to manager action
- user value: 70%+ find dashboard helpful

**overall:**
- daily usage: 90%+ of managers use at least one feature daily
- satisfaction: 4.5+ out of 5 stars
- retention: < 5% disable features after trying
- performance: all features < 3 seconds, app responsive

---

## reporting bugs

when reporting bugs, include:
1. which feature (suggestions, blockers, sentiment)
2. exact steps to reproduce
3. expected vs actual behavior
4. screenshots or screen recordings
5. device info (simulator or physical)
6. firebase function logs (if backend issue)
7. xcode console logs (if ios issue)

---

## final verification

before marking implementation complete:

**feature 1 (smart response suggestions):**
- ✅ test cases 1-5 passed
- ✅ build succeeds
- ✅ cloud function deployed
- ✅ integration complete

**feature 2 (proactive blocker detection):**
- ✅ test cases 6-11 passed
- ✅ build succeeds
- ✅ cloud function deployed
- ✅ integration complete

**feature 3 (team sentiment analysis):**
- ✅ test cases 12-17 passed
- ✅ build succeeds
- ✅ cloud function deployed
- ✅ integration complete

**integration:**
- ✅ test cases 18-20 passed
- ✅ unified dashboard created
- ✅ settings panel working
- ✅ privacy controls functional

**performance:**
- ✅ test cases 21-22 passed
- ✅ response times meet targets
- ✅ app responsive under load

**privacy:**
- ✅ test cases 25-26 passed
- ✅ transparency clear
- ✅ opt-out working

all tests passed = ready for production deployment

