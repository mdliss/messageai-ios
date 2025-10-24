# Advanced AI Features Implementation Tasks

**context:** all rubric requirements are already complete. these tasks implement three advanced, beyond rubric ai features that transform messageai into an indispensable management tool for busy remote managers.

**all tasks have complexity < 7 to ensure manageability** ✅

---

## FEATURE 1: SMART RESPONSE SUGGESTIONS
**saves managers 30-45 minutes per day with ai powered response options**

### Database Schema Tasks

**Task 1: Create Firestore Schema for Response Suggestion Cache**
- **Complexity**: 3/10
- **Dependencies**: None
- **Description**: Extend message document schema to store response suggestions and feedback
- **Details**:
  - Add optional `responseSuggestions` object to message documents
  - Structure: `{ generatedAt, expiresAt, options[] }`
  - Add optional `suggestionFeedback` object: `{ wasShown, wasUsed, selectedOptionId, wasEdited, userRating }`
  - No migration needed (optional fields on existing schema)
- **Test Strategy**: Create test message with suggestion data, verify saves and retrieves correctly
- **Acceptance**: Can store and query suggestion cache from Firestore

**Task 2: Create Swift Model for Response Suggestions**
- **Complexity**: 2/10
- **Dependencies**: Task 1
- **Description**: Create Swift models for response suggestions
- **Details**:
  - Create `ResponseSuggestion.swift` model file in messageAI/Models/
  - Properties: id, text, type (SuggestionType enum), reasoning, confidence
  - Make Identifiable, Codable, Equatable
  - Create `SuggestionType` enum: approve, decline, conditional, delegate
  - Add color and icon computed properties to enum
- **Test Strategy**: Create test instances, verify encoding/decoding works
- **Acceptance**: Model compiles, can be encoded/decoded to/from JSON

### Cloud Function Tasks

**Task 3: Create generateResponseSuggestions Cloud Function Scaffold**
- **Complexity**: 4/10
- **Dependencies**: Task 1
- **Description**: Create basic cloud function structure in functions/src/ai/
- **Details**:
  - Create `functions/src/ai/responseSuggestions.ts`
  - Export function with https.onCall trigger
  - Add auth check: `if (!context.auth) throw error`
  - Parameters: conversationId (string), messageId (string), currentUserId (string)
  - Configuration: timeout 10s, memory 512MB
  - Return stub data: `{ options: [] }`
  - Add to exports in functions/src/index.ts
- **Test Strategy**: Deploy function, call from test script, verify auth works
- **Acceptance**: Function deploys successfully, auth check works, returns stub data

**Task 4: Build AI Prompt Template for Response Suggestions**
- **Complexity**: 5/10
- **Dependencies**: Task 3
- **Description**: Design high quality AI prompt for generating contextual suggestions
- **Details**:
  - System prompt: define role (help busy manager respond efficiently)
  - User prompt template with variables:
    - ${conversationHistory} - last 15-20 messages formatted
    - ${currentMessage} - message requiring response
    - ${managerStyleExamples} - recent manager responses for style matching
  - Request 3-4 diverse suggestions (approve, decline, conditional, delegate)
  - Specify JSON output format with no markdown
  - Test prompt with 10 different conversation samples
  - Measure quality: relevance, diversity, style matching
- **Test Strategy**: Test with variety of request types, verify quality and diversity
- **Acceptance**: Prompt consistently generates 3-4 relevant, diverse, high quality suggestions

**Task 5: Implement Conversation Context Gathering**
- **Complexity**: 4/10
- **Dependencies**: Task 3
- **Description**: Fetch and format conversation history for AI context
- **Details**:
  - Function: `getConversationContext(conversationId, limit)`
  - Query last 15-20 messages from Firestore
  - Format as transcript: "SenderName: message text"
  - Query manager's recent responses from other conversations (last 5-10)
  - Format style examples for prompt
  - Return formatted strings
  - Consider creating reusable utility (used by multiple features)
- **Test Strategy**: Test with various conversation lengths, verify correct formatting
- **Acceptance**: Returns properly formatted context within 500ms

**Task 6: Integrate OpenAI API for Suggestion Generation**
- **Complexity**: 5/10
- **Dependencies**: Tasks 4, 5
- **Description**: Call OpenAI GPT-4o and parse suggestions from response
- **Details**:
  - Get API key: `functions.config().openai.key`
  - Create OpenAI client
  - Call `openai.chat.completions.create` with:
    - model: 'gpt-4o'
    - temperature: 0.7 (creative but consistent)
    - max_tokens: 800
    - messages: system + user prompt
  - Parse JSON response (handle markdown code fences)
  - Validate response structure
  - Handle errors gracefully (invalid JSON, API failures)
  - Return suggestions array
- **Test Strategy**: Test with 10 messages, verify parsing success rate > 95%
- **Acceptance**: Returns parsed suggestions within 3 seconds, handles errors gracefully

**Task 7: Implement Suggestion Caching**
- **Complexity**: 3/10
- **Dependencies**: Task 6
- **Description**: Cache generated suggestions in Firestore to avoid redundant AI calls
- **Details**:
  - Before calling AI, check message doc for cached suggestions
  - If cache exists and not expired (< 5 min old), return cached
  - If conversation continued after message (newer messages exist), invalidate cache
  - After generating suggestions, save to message doc with expiration timestamp
  - Set expiresAt: generatedAt + 5 minutes
- **Test Strategy**: Generate twice for same message, verify second uses cache
- **Acceptance**: Cache hits avoid AI calls, expires after 5 minutes

**Task 8: Deploy and Test Cloud Function**
- **Complexity**: 2/10
- **Dependencies**: Tasks 3-7
- **Description**: Deploy complete function and test end-to-end
- **Details**:
  - Ensure function exported in functions/src/index.ts
  - Run `firebase deploy --only functions:generateResponseSuggestions`
  - Test with real conversation data from Firestore
  - Verify Firebase logs show correct flow
  - Test error cases: invalid IDs, auth failures, AI timeouts
  - Monitor function execution time
- **Test Strategy**: Make 10 test calls with various inputs, verify < 5% error rate
- **Acceptance**: Function deployed to production, working correctly

### Swift Integration Tasks

**Task 9: Create ResponseSuggestionsViewModel**
- **Complexity**: 4/10
- **Dependencies**: Task 2
- **Description**: Build view model to manage suggestion state and API calls
- **Details**:
  - Create `ResponseSuggestionsViewModel.swift` in messageAI/ViewModels/
  - @Published properties: suggestions: [ResponseSuggestion], isLoading: Bool, errorMessage: String?
  - Method: `generateSuggestions(for: Message, in: String, currentUserId: String) async`
  - Use FirebaseConfig.shared.functions to call cloud function
  - Parse result into ResponseSuggestion array
  - Implement timeout (5 seconds)
  - Error handling with user friendly messages
  - Method: `selectSuggestion(_ suggestion, messageId, conversationId)` to track usage
  - Method: `dismissSuggestions()` to clear
- **Test Strategy**: Generate suggestions for test messages, verify state updates correctly
- **Acceptance**: ViewModel compiles, successfully calls cloud function, updates state

**Task 10: Create ResponseSuggestionsCard View**
- **Complexity**: 5/10
- **Dependencies**: Task 9
- **Description**: Build SwiftUI view to display suggestion options
- **Details**:
  - Create `ResponseSuggestionsCard.swift` in messageAI/Views/Chat/
  - Header: sparkles icon + "ai suggestions" text + dismiss button
  - Loading state: progress view + "generating suggestions..."
  - Loaded state: ForEach over suggestions showing SuggestionButton for each
  - Closure: onSelectSuggestion(text: String)
  - Background: Color(.systemGray6), cornerRadius: 12
  - Padding for proper spacing
- **Test Strategy**: Preview with mock suggestions, verify layout and interactions
- **Acceptance**: Card renders correctly, buttons are tappable, dismiss works

**Task 11: Create SuggestionButton Subcomponent**
- **Complexity**: 3/10
- **Dependencies**: Task 2
- **Description**: Build individual suggestion button with type based styling
- **Details**:
  - Create `SuggestionButton.swift` in messageAI/Views/Chat/
  - HStack: icon (based on type) + VStack (text + reasoning)
  - Color based on SuggestionType:
    - approve: green
    - decline: red
    - conditional: orange
    - delegate: blue
  - Text wraps if needed, multilineTextAlignment: .leading
  - Background: Color(.systemBackground), cornerRadius: 8
  - Haptic feedback on tap
- **Test Strategy**: Preview with different types, verify colors and layout
- **Acceptance**: Button renders correctly for all types, tap provides feedback

**Task 12: Integrate Suggestions into ChatView**
- **Complexity**: 6/10
- **Dependencies**: Tasks 9, 10
- **Description**: Add suggestion card to chat view when appropriate
- **Details**:
  - Add @StateObject responseSuggestionsViewModel to ChatView
  - Detect when to show suggestions:
    - Check if message ends with "?"
    - Check for keywords: "can we", "should we", "would you", "need approval", "waiting for"
    - Check if message has priority flag
  - Show ResponseSuggestionsCard below triggering message
  - Position above keyboard, below messages list
  - Auto generate suggestions when detected OR
  - Show "get suggestions" button for manual trigger
  - Handle loading and error states
- **Test Strategy**: Send test messages, verify suggestions appear for right messages only
- **Acceptance**: Suggestions show for appropriate messages, hidden for casual chat

**Task 13: Implement Suggestion Selection and Insertion**
- **Complexity**: 4/10
- **Dependencies**: Task 12
- **Description**: Handle user selecting suggestion and inserting into message input
- **Details**:
  - When suggestion tapped, call viewModel.selectSuggestion (tracks usage)
  - Insert suggestion.text into message input field (@Binding messageText)
  - Don't auto-send (user can edit first)
  - Dismiss suggestion card
  - Provide haptic feedback
  - Cursor positioned at end of inserted text
- **Test Strategy**: Tap suggestions, verify text inserts, user can edit before sending
- **Acceptance**: Selected suggestion inserted into input, user can edit, then send

**Task 14: Add Suggestion Feedback Mechanism**
- **Complexity**: 3/10
- **Dependencies**: Task 13
- **Description**: Allow users to rate suggestion quality for future improvement
- **Details**:
  - Add thumbs up/down buttons to suggestion card (optional)
  - When user provides feedback, update Firestore:
    - Path: conversations/{id}/messages/{id}
    - Update suggestionFeedback.userRating: 'helpful' | 'not_helpful'
  - Show subtle "thanks for feedback" confirmation
  - Future: use feedback data to tune prompts
- **Test Strategy**: Provide feedback, verify saved to Firestore
- **Acceptance**: Feedback buttons work, data saves correctly

---

## FEATURE 2: PROACTIVE BLOCKER DETECTION  
**prevents productivity loss by catching team member blockers early**

### Database Schema Tasks

**Task 15: Create Firestore Schema for Blockers**
- **Complexity**: 3/10
- **Dependencies**: None
- **Description**: Design schema for storing detected blockers
- **Details**:
  - Create subcollection: conversations/{id}/blockers/{blockerId}
  - Fields: id, detectedAt, messageId (reference), blockedUserId, blockedUserName
  - Fields: blockerDescription, blockerType, severity, status
  - Fields: suggestedActions[], conversationId, confidence
  - Fields: resolvedAt, resolvedBy, resolutionNotes, snoozedUntil, managerMarkedFalsePositive
  - Create composite index for querying: status + severity + detectedAt
- **Test Strategy**: Create test blocker docs, query by status and severity
- **Acceptance**: Can save and efficiently query blockers

**Task 16: Create Firestore Schema for Blocker Alerts**
- **Complexity**: 2/10
- **Dependencies**: Task 15
- **Description**: Design schema for user specific blocker notifications
- **Details**:
  - Create subcollection: users/{userId}/blockerAlerts/{alertId}
  - Fields: id, blockerId (reference), conversationId, severity, blockerDescription
  - Fields: createdAt, read (bool), dismissed (bool)
  - Create index for querying unread alerts: read + createdAt
- **Test Strategy**: Create test alerts, query unread for user
- **Acceptance**: Can save and query alerts by read status

**Task 17: Create Swift Models for Blocker Data**
- **Complexity**: 3/10
- **Dependencies**: Tasks 15, 16
- **Description**: Create Swift models for blockers and alerts
- **Details**:
  - Create `Blocker.swift` in messageAI/Models/
  - All fields from schema, make Codable, Identifiable, Equatable
  - Create enums: BlockerType, BlockerSeverity (with color/icon), BlockerStatus
  - Create `BlockerAlert.swift` model
  - Add computed properties for display (time elapsed, severity color, etc)
- **Test Strategy**: Create test instances, verify encoding/decoding
- **Acceptance**: Models compile, can encode/decode from Firestore

### Cloud Function Tasks

**Task 18: Create detectBlocker Cloud Function Scaffold**
- **Complexity**: 4/10
- **Dependencies**: Task 15
- **Description**: Create basic function structure for blocker detection
- **Details**:
  - Create `functions/src/ai/blockerDetection.ts`
  - Export function with https.onCall trigger
  - Auth check
  - Parameters: conversationId, messageId
  - Configuration: timeout 15s, memory 512MB
  - Return stub: `{ blocker: null }`
  - Add to index.ts exports
- **Test Strategy**: Deploy, call with test data, verify structure
- **Acceptance**: Function deploys successfully

**Task 19: Build AI Prompt for Blocker Detection**
- **Complexity**: 5/10
- **Dependencies**: Task 18
- **Description**: Design prompt to accurately identify blockers with low false positives
- **Details**:
  - System prompt: define what constitutes a blocker
  - Provide examples of blocker patterns:
    - Explicit: "i'm blocked on..."
    - Approval: "waiting for approval..."
    - Resource: "don't have access to..."
    - Technical: "error keeps happening..."
    - People: "waiting for [person]..."
  - Request classification: isBlocked, description, type, severity, suggestedActions, confidence
  - Specify JSON output format
  - Severity criteria clearly defined
  - Test with 20 messages (10 blockers, 10 not blockers)
  - Measure accuracy and false positive rate
- **Test Strategy**: Test accuracy > 85%, false positives < 10%
- **Acceptance**: Prompt accurately identifies blockers with acceptable false positive rate

**Task 20: Implement Blocker Context Gathering**
- **Complexity**: 3/10
- **Dependencies**: Task 18
- **Description**: Fetch message and surrounding context for analysis
- **Details**:
  - Fetch target message by ID
  - Fetch 10-20 surrounding messages for context
  - Format as transcript with timestamps
  - Timestamps help detect "time based patterns" (long waits)
  - Return formatted context string
- **Test Strategy**: Verify context includes enough info for accurate analysis
- **Acceptance**: Returns properly formatted context with timestamps

**Task 21: Integrate OpenAI API for Blocker Detection**
- **Complexity**: 5/10
- **Dependencies**: Tasks 19, 20
- **Description**: Call OpenAI and parse blocker analysis
- **Details**:
  - Use GPT-4o model
  - Temperature: 0.3 (consistent, not creative)
  - Max tokens: 500
  - Parse JSON response (handle markdown)
  - Extract: isBlocked, description, type, severity, suggestedActions, confidence
  - Only consider valid if confidence > 0.7
  - Return null if not blocker or low confidence
- **Test Strategy**: Test with 20 messages, verify parsing and confidence filtering
- **Acceptance**: Returns structured blocker data or null correctly

**Task 22: Save Detected Blockers to Firestore**
- **Complexity**: 4/10
- **Dependencies**: Tasks 15, 21
- **Description**: Save blocker when detected with high confidence
- **Details**:
  - If isBlocked = true && confidence > 0.7:
  - Create document in conversations/{id}/blockers/
  - Save all blocker fields
  - Set status = 'active'
  - Set timestamps
  - Return blocker ID
- **Test Strategy**: Detect blocker, verify saved with all fields correctly
- **Acceptance**: Blockers save to Firestore correctly

**Task 23: Implement Blocker Notification Logic**
- **Complexity**: 4/10
- **Dependencies**: Tasks 16, 22
- **Description**: Create alerts and send notifications for critical/high blockers
- **Details**:
  - Check blocker severity
  - If critical or high:
    - Get conversation participants
    - For each participant (except blocked person):
      - Create blockerAlert document in users/{id}/blockerAlerts/
      - Send push notification (use existing notification service pattern)
      - Notification text: "[Person] is blocked on [description]"
  - Don't notify for medium/low severity
  - Batch if multiple blockers detected within 5 minutes
- **Test Strategy**: Detect critical blocker, verify notifications sent correctly
- **Acceptance**: Notifications sent only for critical/high severity

**Task 24: Create Firestore Trigger for Auto Blocker Detection**
- **Complexity**: 5/10
- **Dependencies**: Task 21
- **Description**: Trigger blocker detection automatically on new messages
- **Details**:
  - Create onCreate trigger: functions.firestore.document('conversations/{id}/messages/{msgId}').onCreate
  - Only process if message.type === 'text'
  - Check for blocker keywords first (fast filter):
    - 'blocked', 'stuck', 'waiting for', "can't proceed", 'need help', etc
  - If keywords found, call detectBlocker asynchronously
  - Don't block message creation (background processing)
  - Handle errors gracefully (log, don't throw)
- **Test Strategy**: Send message with blocker keywords, verify trigger fires
- **Acceptance**: Blocker detection happens automatically in background

**Task 25: Deploy and Test Blocker Detection Functions**
- **Complexity**: 2/10
- **Dependencies**: Tasks 18-24
- **Description**: Deploy all functions and test end-to-end
- **Details**:
  - Ensure all functions exported
  - Deploy: `firebase deploy --only functions`
  - Test manual detection call
  - Test automatic trigger on message creation
  - Verify logs show correct flow
  - Test with various blocker types and severities
- **Test Strategy**: Send 10 test messages, verify detection and notifications work
- **Acceptance**: Functions deployed, working correctly in production

### Swift Integration Tasks

**Task 26: Create BlockerDashboardViewModel**
- **Complexity**: 5/10
- **Dependencies**: Task 17
- **Description**: Build view model to manage blocker data
- **Details**:
  - Create `BlockerDashboardViewModel.swift` in ViewModels/
  - @Published properties: activeBlockers: [Blocker], isLoading, errorMessage
  - Method: `loadActiveBlockers(for userId: String) async`
    - Query all conversations user participates in
    - For each conversation, query active blockers
    - Merge all blockers into single array
    - Sort by severity (critical first) then time (oldest first)
  - Method: `markResolved(_ blocker, notes: String?, currentUserId) async`
  - Method: `snooze(_ blocker, duration: TimeInterval) async`
  - Method: `markFalsePositive(_ blocker) async`
- **Test Strategy**: Load blockers for test user, verify sorting correct
- **Acceptance**: ViewModel loads and sorts blockers correctly

**Task 27: Create BlockerCard View Component**
- **Complexity**: 4/10
- **Dependencies**: Task 17
- **Description**: Build card to display individual blocker
- **Details**:
  - Create `BlockerCard.swift` in Views/
  - Show: severity indicator (colored icon + text), time elapsed
  - Show: blocked user name with avatar
  - Show: blocker description
  - Show: blocker type
  - Show: suggested actions as bullet list
  - Buttons: "mark resolved", "snooze" (menu with options), "false positive"
  - Sheet for resolution notes (optional)
  - Computed property for time elapsed formatting
- **Test Strategy**: Preview with blockers of different severities
- **Acceptance**: Card displays blocker info clearly with all actions

**Task 28: Create BlockerDashboardView**
- **Complexity**: 5/10
- **Dependencies**: Tasks 26, 27
- **Description**: Build main blocker dashboard
- **Details**:
  - Create `BlockerDashboardView.swift` in Views/
  - NavigationView with title "team blockers"
  - Empty state: "no active blockers 🎉 your team is flowing smoothly"
  - List of BlockerCard for each active blocker
  - Pull to refresh functionality
  - Filter options (future enhancement): all, critical only, by member
  - Load blockers on appear using .task
- **Test Strategy**: Display with test blockers, verify layout and refresh
- **Acceptance**: Dashboard shows blockers, empty state, pull to refresh works

**Task 29: Implement Blocker Resolution Actions**
- **Complexity**: 4/10
- **Dependencies**: Task 28
- **Description**: Wire up resolution, snooze, and false positive actions
- **Details**:
  - "Mark resolved":
    - Update blocker doc: status = 'resolved', resolvedAt, resolvedBy
    - Optional resolution notes
    - Remove from active list locally
  - "Snooze":
    - Menu with options: 1 hour, 4 hours, 1 day
    - Update blocker doc: status = 'snoozed', snoozedUntil
    - Remove from active list
  - "False positive":
    - Update blocker doc: status = 'false_positive', managerMarkedFalsePositive = true
    - Remove from active list
  - All actions update Firestore
- **Test Strategy**: Resolve, snooze, mark false positive, verify Firestore updates
- **Acceptance**: All actions work, Firestore updates correctly

**Task 30: Add Blocker Dashboard to Navigation**
- **Complexity**: 3/10
- **Dependencies**: Task 28
- **Description**: Make blocker dashboard accessible from main app navigation
- **Details**:
  - Add navigation link/tab for blocker dashboard
  - Icon: exclamation mark triangle or similar
  - Badge showing count of critical + high severity blockers
  - Accessible from main tab bar or menu
  - Badge updates in real time when new blockers detected
- **Test Strategy**: Navigate to dashboard from main app, verify badge count
- **Acceptance**: Dashboard accessible, badge shows correct count

---

## FEATURE 3: TEAM SENTIMENT ANALYSIS
**spots morale issues 2-3 days earlier than managers normally notice**

### Database Schema Tasks

**Task 31: Add Sentiment Fields to Message Documents**
- **Complexity**: 2/10
- **Dependencies**: None
- **Description**: Extend message schema to store sentiment data
- **Details**:
  - Add optional field: sentimentScore (number, -1.0 to 1.0)
  - Add optional object: sentimentAnalysis
    - score: number
    - emotions: string[]
    - confidence: number
    - analyzedAt: timestamp
    - reasoning: string
  - No migration needed (optional fields)
- **Test Strategy**: Create message with sentiment data, verify saves correctly
- **Acceptance**: Sentiment fields save and retrieve from Firestore

**Task 32: Create Sentiment Aggregates Collections**
- **Complexity**: 3/10
- **Dependencies**: Task 31
- **Description**: Design schema for aggregate sentiment tracking
- **Details**:
  - Collection: sentimentTracking/userDaily/aggregates/{date_userId}
    - Fields: userId, date (yyyy-mm-dd), averageSentiment, messageCount, emotionsDetected {}, trend
  - Collection: sentimentTracking/userWeekly/{userId}
    - Fields: userId, weekStartDate, dailyScores {}, averageSentiment, trend
  - Collection: sentimentTracking/teamDaily/aggregates/{date_conversationId}
    - Fields: conversationId, date, averageSentiment, memberSentiments {}, trend
  - Collection: sentimentTracking/teamWeekly/{conversationId}
    - Fields: conversationId, weekStartDate, dailyScores {}, averageSentiment, trend
  - Create indexes for date range queries
- **Test Strategy**: Create aggregate docs, query by date range
- **Acceptance**: Can save and query aggregates efficiently

**Task 33: Create Swift Models for Sentiment Data**
- **Complexity**: 3/10
- **Dependencies**: Tasks 31, 32
- **Description**: Create Swift models for sentiment
- **Details**:
  - Create `SentimentData.swift` in Models/
  - Properties: userId, userName, averageSentiment, trend, messageCount, emotionsDetected, lastAnalyzed
  - Enum: SentimentTrend (improving, stable, declining) with icon and color
  - Extensions: sentimentCategory (very positive to very negative), sentimentColor
  - Make Codable, Identifiable
- **Test Strategy**: Create instances, verify computed properties correct
- **Acceptance**: Models compile, computed properties return correct values

### Cloud Function Tasks

**Task 34: Create analyzeSentiment Cloud Function Scaffold**
- **Complexity**: 4/10
- **Dependencies**: Task 31
- **Description**: Create basic function structure for sentiment analysis
- **Details**:
  - Create `functions/src/ai/sentiment.ts`
  - Export function with https.onCall trigger
  - Auth check
  - Parameters: conversationId, messageId
  - Configuration: timeout 10s, memory 512MB
  - Return stub: `{ sentiment: null }`
  - Add to index.ts exports
- **Test Strategy**: Deploy, call with test data
- **Acceptance**: Function deploys successfully

**Task 35: Build AI Prompt for Sentiment Analysis**
- **Complexity**: 5/10
- **Dependencies**: Task 34
- **Description**: Design prompt for accurate context aware sentiment detection
- **Details**:
  - System prompt: analyze emotional tone and sentiment
  - Provide context: recent conversation messages
  - Request:
    - Sentiment score: -1.0 to +1.0
    - Specific emotions: frustrated, excited, stressed, etc
    - Confidence: 0.0 to 1.0
    - Brief reasoning
  - Examples of positive, neutral, negative messages
  - Note importance of context (same words, different meanings)
  - Distinguish sarcasm vs genuine
  - JSON output format
  - Test with 20 messages, compare to human assessment
  - Measure accuracy (80%+ target)
- **Test Strategy**: Test accuracy vs human labels
- **Acceptance**: 80%+ correlation with human sentiment assessment

**Task 36: Implement Sentiment Context Gathering**
- **Complexity**: 3/10
- **Dependencies**: Task 34
- **Description**: Fetch message and surrounding context
- **Details**:
  - Fetch target message
  - Fetch 5-10 surrounding messages for tone context
  - Format as transcript with sender names
  - Return formatted context
- **Test Strategy**: Verify context sufficient for accurate analysis
- **Acceptance**: Returns formatted context

**Task 37: Integrate OpenAI API for Sentiment Analysis**
- **Complexity**: 5/10
- **Dependencies**: Tasks 35, 36
- **Description**: Call OpenAI and parse sentiment response
- **Details**:
  - Use GPT-4o model
  - Temperature: 0.2 (consistent analysis)
  - Max tokens: 300
  - Parse JSON response
  - Extract: score, emotions[], confidence, reasoning
  - Validate score in range [-1.0, 1.0]
  - Only save if confidence > 0.5
  - Return null if low confidence
- **Test Strategy**: Analyze 20 messages, verify parsing
- **Acceptance**: Returns structured sentiment data correctly

**Task 38: Save Sentiment to Message Documents**
- **Complexity**: 3/10
- **Dependencies**: Tasks 31, 37
- **Description**: Update message with sentiment analysis results
- **Details**:
  - Update message document with sentimentScore
  - Update message document with sentimentAnalysis object
  - Set analyzedAt timestamp
  - Only update if confidence > 0.5
  - Return success
- **Test Strategy**: Analyze message, verify Firestore updated
- **Acceptance**: Sentiment data saved to messages

**Task 39: Create Firestore Trigger for Auto Sentiment Analysis**
- **Complexity**: 4/10
- **Dependencies**: Task 37
- **Description**: Trigger sentiment analysis on new text messages
- **Details**:
  - Create onCreate trigger for messages
  - Only process if message.type === 'text'
  - Call analyzeSentiment asynchronously
  - Don't block message creation
  - Handle errors gracefully (log, don't throw)
- **Test Strategy**: Send text message, verify sentiment analyzed automatically
- **Acceptance**: Sentiment analysis happens in background

**Task 40: Create Scheduled Function for Sentiment Aggregates**
- **Complexity**: 6/10
- **Dependencies**: Tasks 32, 38
- **Description**: Calculate hourly/daily aggregate sentiment scores
- **Details**:
  - Create scheduled function: `functions.pubsub.schedule('every 1 hours')`
  - For each user:
    - Query messages from past 24 hours with sentiment
    - Calculate average sentiment
    - Count messages
    - Aggregate emotions
    - Determine trend (compare to yesterday)
    - Save to userDaily aggregates
  - For each team (group conversation):
    - Get member sentiments for today
    - Calculate team average
    - Determine trend
    - Save to teamDaily aggregates
  - Check for significant drops, create alerts if needed
- **Test Strategy**: Manually trigger function, verify aggregates calculated
- **Acceptance**: Aggregates calculate correctly hourly

**Task 41: Implement Sentiment Alert Logic**
- **Complexity**: 4/10
- **Dependencies**: Task 40
- **Description**: Detect significant sentiment drops and alert manager
- **Details**:
  - In aggregate function, compare to previous periods
  - Triggers:
    - Team sentiment drops 20+ points in a week
    - Individual negative for 3+ consecutive days
    - 3+ members negative same day
  - Create alert document
  - Send push notification to managers
  - Alert describes what changed
- **Test Strategy**: Create drop scenario, verify alert sent
- **Acceptance**: Alerts trigger correctly for significant changes

**Task 42: Deploy and Test Sentiment Functions**
- **Complexity**: 2/10
- **Dependencies**: Tasks 34-41
- **Description**: Deploy all sentiment functions and test
- **Details**:
  - Ensure all exported
  - Deploy: `firebase deploy --only functions`
  - Test automatic analysis on message creation
  - Test scheduled aggregate calculation (manually trigger)
  - Test alert triggering
  - Verify logs
- **Test Strategy**: Send messages, trigger aggregates, verify alerts
- **Acceptance**: All functions deployed and working

### Swift Integration Tasks

**Task 43: Create SentimentDashboardViewModel**
- **Complexity**: 6/10
- **Dependencies**: Task 33
- **Description**: Build view model for sentiment dashboard
- **Details**:
  - Create `SentimentDashboardViewModel.swift` in ViewModels/
  - @Published properties:
    - teamSentiment: Double (-1.0 to 1.0)
    - sentimentTrend: [Date: Double]
    - memberSentiments: [SentimentData]
    - isLoading, errorMessage
  - Method: `loadTeamSentiment(for conversationId: String) async`
    - Fetch team aggregate for today
    - Fetch trend data (past 7 days)
    - Fetch individual member aggregates
    - Sort members by sentiment (negative first)
  - Use date formatting for queries
  - Handle missing data gracefully
- **Test Strategy**: Load sentiment for test conversation, verify data loads
- **Acceptance**: ViewModel loads complete sentiment data

**Task 44: Create SentimentTrendGraph Component**
- **Complexity**: 5/10
- **Dependencies**: Task 43
- **Description**: Build graph to visualize sentiment trends
- **Details**:
  - Create `SentimentTrendGraph.swift` in Views/
  - Use Swift Charts framework
  - X-axis: dates (past 7 or 30 days)
  - Y-axis: sentiment score (convert -1 to 1 → 0 to 100 for display)
  - Line chart showing trend
  - Color gradient: green (positive) to red (negative)
  - Show current value and change indicator
  - Handle empty data (show placeholder)
- **Test Strategy**: Preview with test trend data, verify graph renders
- **Acceptance**: Graph displays sentiment trend clearly

**Task 45: Create TeamSentimentCard Component**
- **Complexity**: 4/10
- **Dependencies**: Tasks 33, 44
- **Description**: Build card showing overall team sentiment
- **Details**:
  - Create `TeamSentimentCard.swift` in Views/
  - Circular sentiment indicator (colored based on score)
  - Display score (convert to 0-100 scale)
  - Show sentiment category text (very positive, neutral, etc)
  - Embed SentimentTrendGraph
  - Show quick stats: "↑ 5% this week"
  - Background color subtle hint based on sentiment
- **Test Strategy**: Preview with different sentiment values
- **Acceptance**: Card displays team sentiment clearly

**Task 46: Create MemberSentimentCard Component**
- **Complexity**: 4/10
- **Dependencies**: Task 33
- **Description**: Build card for individual member sentiment
- **Details**:
  - Create `MemberSentimentCard.swift` in Views/
  - Show member avatar and name
  - Show sentiment score and colored indicator dot
  - Show trend arrow (↑ improving, → stable, ↓ declining)
  - Show top 2-3 emotions detected
  - Tappable to see detailed view
  - Card background subtle tint based on sentiment
- **Test Strategy**: Preview with test member data
- **Acceptance**: Card displays member sentiment clearly

**Task 47: Create SentimentDashboardView**
- **Complexity**: 5/10
- **Dependencies**: Tasks 43, 45, 46
- **Description**: Build main sentiment dashboard
- **Details**:
  - Create `SentimentDashboardView.swift` in Views/
  - NavigationView title: "team sentiment"
  - ScrollView containing:
    - TeamSentimentCard at top
    - "team members" section header
    - List of MemberSentimentCard for each member
  - Pull to refresh
  - Loading state
  - Empty state if no data
  - Load data on appear using .task
- **Test Strategy**: Display with test data, verify layout
- **Acceptance**: Dashboard shows complete sentiment overview

**Task 48: Create Individual Sentiment Detail View**
- **Complexity**: 5/10
- **Dependencies**: Tasks 43, 44
- **Description**: Build detailed view for individual member sentiment
- **Details**:
  - Create `IndividualSentimentDetailView.swift` in Views/
  - Show member info and avatar at top
  - Show sentiment history graph (past 30 days)
  - Show recent messages with negative sentiment (with context)
  - Show emotions detected over time (bar chart or list)
  - Suggested actions for manager:
    - "schedule 1-on-1 check-in"
    - "ask if they need support"
    - "acknowledge concerns"
  - Privacy note at bottom
  - Buttons: "check in" (message), "view conversation"
- **Test Strategy**: Preview with test member data
- **Acceptance**: Detail view provides actionable insights

**Task 49: Add Sentiment Dashboard to Navigation**
- **Complexity**: 3/10
- **Dependencies**: Task 47
- **Description**: Make sentiment dashboard accessible
- **Details**:
  - Add to conversation detail view (for group chats)
  - Or add to main navigation
  - Icon: chart with heart or mood face
  - Only show for group conversations (not one-on-one)
  - Badge if significant sentiment drop detected (optional)
- **Test Strategy**: Navigate to sentiment dashboard from conversation
- **Acceptance**: Dashboard accessible from navigation

---

## INTEGRATION & POLISH

**Task 50: Create Unified AI Dashboard View**
- **Complexity**: 6/10
- **Dependencies**: Tasks 14, 30, 49 (all three features complete)
- **Description**: Build single dashboard showing all AI insights
- **Details**:
  - Create `UnifiedAIDashboardView.swift` in Views/
  - Sections showing:
    - Response suggestions available (count)
    - Active blockers (count, show top 2 by severity)
    - Team sentiment (score, trend indicator)
    - Priority messages (existing feature - count)
    - Action items (existing feature - count pending)
    - Recent AI insights (summaries, decisions from existing features)
  - Each section tappable to navigate to detail view
  - Refresh all data on load
  - Show last updated timestamp
  - Accessible from main navigation
- **Test Strategy**: Display dashboard, verify all sections show correct data
- **Acceptance**: Unified dashboard provides complete AI overview

**Task 51: Create AI Features Settings Panel**
- **Complexity**: 4/10
- **Dependencies**: None (can build anytime)
- **Description**: Build settings view for managing AI features
- **Details**:
  - Create `AIFeaturesSettingsView.swift` in Views/Settings/
  - Form with sections:
    - Smart response suggestions (toggle enable)
    - Blocker detection (toggle enable, toggle notifications)
    - Sentiment analysis (toggle enable, toggle alerts)
    - Privacy section with explanations
  - Store preferences in UserDefaults (@AppStorage)
  - Sync to Firestore user.preferences
  - Link to detailed privacy info
  - Clear descriptions of what each feature does
- **Test Strategy**: Toggle features, verify preferences save
- **Acceptance**: Settings panel controls all features

**Task 52: Implement Shared Context Gathering Utility**
- **Complexity**: 4/10
- **Dependencies**: Tasks 5, 20, 36 (context gathering tasks)
- **Description**: Create DRY utility for conversation context
- **Details**:
  - Create `conversationUtils.ts` in functions/src/ai/utils/
  - Function: `getConversationContext(conversationId, limit)`
  - Returns formatted transcript
  - Cache results for 5 minutes (in memory or Firestore)
  - Check cache before querying Firestore
  - Used by all three AI features
  - Reduces code duplication and Firestore reads
- **Test Strategy**: Call from multiple features, verify caching works
- **Acceptance**: Context gathering is DRY, cached appropriately

**Task 53: Optimize AI API Calls and Costs**
- **Complexity**: 5/10
- **Dependencies**: Tasks 6, 21, 37 (AI integration tasks)
- **Description**: Implement strategies to reduce AI costs
- **Details**:
  - Consider using GPT-4o-mini for simpler analyses
  - Batch multiple analyses in single AI call where possible
  - Implement request deduplication (same message analyzed multiple times)
  - Add per user rate limiting (prevent abuse)
  - Monitor costs with detailed logging
  - Cache aggressively
  - Consider queuing non urgent analyses
- **Test Strategy**: Monitor AI costs before and after optimization
- **Acceptance**: AI costs reduced by 30%+ without quality loss

**Task 54: Add Comprehensive Logging and Error Handling**
- **Complexity**: 4/10
- **Dependencies**: All cloud function tasks
- **Description**: Ensure proper logging and error handling across all functions
- **Details**:
  - Add timestamps to all logs
  - Log: function entry, AI call start/end, DB operations, errors
  - Catch all errors gracefully
  - Return user friendly error messages to client
  - Don't expose internal errors
  - Set up error monitoring/alerting for critical failures
  - Use console.log, console.error appropriately
- **Test Strategy**: Trigger errors, verify logging and error messages
- **Acceptance**: Comprehensive logs, graceful error handling

**Task 55: Polish UI/UX Across All Features**
- **Complexity**: 5/10
- **Dependencies**: All UI tasks
- **Description**: Ensure consistent, polished UI across features
- **Details**:
  - Consistent spacing (16pt padding standard)
  - Consistent colors (use theme colors)
  - Consistent fonts (system fonts with proper weights)
  - Smooth animations (fade in/out, slide, scale)
  - Loading states for all async operations (ProgressView with text)
  - Empty states with helpful messaging and icons
  - Error states with retry buttons
  - Haptic feedback on all button taps
  - Dark mode support (use Color(.systemBackground) etc)
  - Accessibility labels on all interactive elements
- **Test Strategy**: Review all views, test all interactions, verify polish
- **Acceptance**: UI is polished, consistent, responsive, accessible

**Task 56: Add Privacy Explanations and Transparency**
- **Complexity**: 3/10
- **Dependencies**: Task 51
- **Description**: Provide clear privacy information
- **Details**:
  - Add privacy section in settings
  - Explain what data each feature analyzes
  - Emphasize supportive purpose (team health, not surveillance)
  - Explain opt out options clearly
  - Link to full privacy policy
  - First time use: show AI features overview with privacy info
  - "Learn more" buttons throughout app
  - Use clear, non technical language
- **Test Strategy**: Review privacy explanations for clarity and completeness
- **Acceptance**: Privacy information clear, transparent, accessible

**Task 57: Implement Opt Out Mechanisms**
- **Complexity**: 4/10
- **Dependencies**: Task 51
- **Description**: Allow users to disable features completely
- **Details**:
  - Respect settings toggles in all features
  - If feature disabled:
    - Don't show UI components
    - Don't run background processing (check in cloud functions)
    - Don't make AI API calls
  - Save preferences to Firestore user.preferences
  - Sync across devices
  - Can re enable anytime
  - Partial opt out (e.g., analysis yes, notifications no)
- **Test Strategy**: Disable each feature, verify completely stops
- **Acceptance**: Opt out fully prevents feature from running

**Task 58: Write Comprehensive Testing Documentation**
- **Complexity**: 4/10
- **Dependencies**: All tasks
- **Description**: Document how to test all features
- **Details**:
  - Create `TESTING_GUIDE_AI_FEATURES.md` in docs/
  - For each feature:
    - Test scenarios with step by step instructions
    - Expected results
    - How to verify (what to look for)
    - Edge cases to test
  - Include iOS simulator test cases
  - Include manual test scripts
  - Include automated test requirements (future)
- **Test Strategy**: Follow guide to test all features
- **Acceptance**: Comprehensive testing documentation complete

**Task 59: Build with XcodeBuildMCP and Fix All Errors**
- **Complexity**: 5/10
- **Dependencies**: All Swift tasks
- **Description**: Ensure project builds cleanly
- **Details**:
  - Use XcodeBuildMCP to build project
  - Fix all compilation errors
  - Fix all warnings
  - Ensure all new files added to Xcode project
  - Verify all imports correct
  - Run SwiftLint if configured, fix issues
  - Verify Info.plist permissions if needed
- **Test Strategy**: Build succeeds with zero errors, zero warnings
- **Acceptance**: Clean build

**Task 60: Comprehensive Testing with iOS Simulator**
- **Complexity**: 6/10
- **Dependencies**: Task 59 (clean build)
- **Description**: End to end testing using iOS simulators
- **Details**:
  - Launch 3 simulators (manager + 2 team members)
  - Test Feature 1 (Smart Response Suggestions):
    - Send messages requiring responses
    - Verify suggestions appear and are relevant
    - Test selection, editing, sending
    - Test feedback mechanism
  - Test Feature 2 (Blocker Detection):
    - Send blocker messages with keywords
    - Verify detection and classification correct
    - Verify notifications sent for critical/high
    - Test blocker dashboard and resolution
  - Test Feature 3 (Sentiment Analysis):
    - Send messages with varying sentiment
    - Verify sentiment analyzed correctly
    - Check sentiment dashboard data
    - Verify trend graphs display
  - Test unified AI dashboard
  - Test settings and opt out
  - Document all tests with screenshots
  - Note any bugs or issues found
- **Test Strategy**: Follow comprehensive test plan, document results
- **Acceptance**: All features working as expected, issues documented

---

## Summary

**Total Tasks**: 60
**All tasks complexity < 7**: ✅ YES
**Highest complexity**: 6/10
**Average complexity**: ~4.2/10

**Breakdown by Feature:**
- Feature 1 (Smart Response Suggestions): 14 tasks
- Feature 2 (Proactive Blocker Detection): 16 tasks
- Feature 3 (Team Sentiment Analysis): 19 tasks
- Integration & Polish: 11 tasks

**Estimated Timeline:**
- Phase 1 (Foundation): Tasks 1-17 (4-5 days)
- Phase 2 (Core Services): Tasks 18-42 (7-8 days)
- Phase 3 (Swift UI): Tasks 43-49 (4-5 days)
- Phase 4 (Integration & Polish): Tasks 50-60 (3-4 days)

**Total: 18-22 days** (1 developer)

**Features Implementation:**
- Can develop in parallel (no hard dependencies)
- Each feature tested independently
- Integration happens in final phase
- All build on proven patterns from existing AI features

**Key Success Factors:**
- All tasks are specific and actionable
- All have clear acceptance criteria
- All can be tested independently
- Logical dependency ordering
- Manageable complexity (all < 7)
- Realistic timeline estimates
