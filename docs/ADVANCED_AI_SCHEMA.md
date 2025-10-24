# Advanced AI Features - Firestore Schema Extensions

This document defines the Firestore schema extensions for the three advanced AI features.

## Feature 1: Smart Response Suggestions

### Message Document Extensions

**Collection**: `conversations/{conversationId}/messages/{messageId}`

**New Optional Fields**:

```typescript
// Response suggestions cache
responseSuggestions?: {
  generatedAt: Timestamp;
  expiresAt: Timestamp;  // generatedAt + 5 minutes
  options: Array<{
    id: string;           // unique ID for this suggestion
    text: string;         // suggested response text
    type: 'approve' | 'decline' | 'conditional' | 'delegate';
    reasoning: string;    // brief explanation why this fits
    confidence: number;   // 0.0 to 1.0
  }>;
}

// Suggestion usage feedback
suggestionFeedback?: {
  wasShown: boolean;           // were suggestions displayed to user
  wasUsed: boolean;            // did user select a suggestion
  selectedOptionId?: string;   // which suggestion was selected
  wasEdited: boolean;          // did user edit before sending
  userRating?: 'helpful' | 'not_helpful';  // explicit feedback
  createdAt: Timestamp;
}
```

**Schema Notes**:
- These fields are **optional** - no migration needed for existing messages
- `responseSuggestions` cache expires after 5 minutes
- Cache invalidated if conversation continues (newer messages exist after this message)
- `suggestionFeedback` tracks usage for learning and improvement

**Example Message Document**:
```json
{
  "id": "msg123",
  "conversationId": "conv456",
  "senderId": "user789",
  "senderName": "Team Member",
  "type": "text",
  "text": "Can we push the deadline to next Friday?",
  "createdAt": "2025-10-24T10:30:00Z",
  "status": "delivered",
  
  // NEW: Response suggestions (cached)
  "responseSuggestions": {
    "generatedAt": "2025-10-24T10:30:05Z",
    "expiresAt": "2025-10-24T10:35:05Z",
    "options": [
      {
        "id": "sug1",
        "text": "Yes, let's move it to Friday the 25th. Please update the team.",
        "type": "approve",
        "reasoning": "Approves request and provides clear next steps",
        "confidence": 0.92
      },
      {
        "id": "sug2",
        "text": "What's causing the delay? If it's blockers, let's discuss.",
        "type": "conditional",
        "reasoning": "Asks clarifying question before deciding",
        "confidence": 0.88
      }
    ]
  },
  
  // NEW: Feedback (after manager uses suggestion)
  "suggestionFeedback": {
    "wasShown": true,
    "wasUsed": true,
    "selectedOptionId": "sug1",
    "wasEdited": false,
    "userRating": "helpful",
    "createdAt": "2025-10-24T10:30:15Z"
  }
}
```

---

## Feature 2: Proactive Blocker Detection

### New Collection: Blockers

**Collection**: `conversations/{conversationId}/blockers/{blockerId}`

**Document Structure**:
```typescript
{
  id: string;                    // auto-generated blocker ID
  detectedAt: Timestamp;         // when blocker was detected
  messageId: string;             // reference to message that triggered detection
  blockedUserId: string;         // ID of person who is blocked
  blockedUserName: string;       // display name of blocked person
  blockerDescription: string;    // AI-generated summary (5-10 words)
  blockerType: 'explicit' | 'approval' | 'resource' | 'technical' | 'people' | 'time_based';
  severity: 'critical' | 'high' | 'medium' | 'low';
  status: 'active' | 'resolved' | 'snoozed' | 'false_positive';
  suggestedActions: string[];    // AI-generated actions (2-3 items)
  conversationId: string;        // reference back to conversation
  
  // Resolution tracking
  resolvedAt?: Timestamp;
  resolvedBy?: string;           // manager user ID
  resolutionNotes?: string;      // optional notes
  
  // Snooze tracking
  snoozedUntil?: Timestamp;
  
  // Learning / quality
  confidence: number;            // 0.0 to 1.0 (AI confidence)
  managerMarkedFalsePositive: boolean;  // for improving detection
}
```

**Firestore Index Required**:
```json
{
  "collectionGroup": "blockers",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "status", "order": "ASCENDING"},
    {"fieldPath": "severity", "order": "ASCENDING"},
    {"fieldPath": "detectedAt", "order": "DESCENDING"}
  ]
}
```

**Example Blocker Document**:
```json
{
  "id": "blocker789",
  "detectedAt": "2025-10-24T10:00:00Z",
  "messageId": "msg456",
  "blockedUserId": "user123",
  "blockedUserName": "Sarah Chen",
  "blockerDescription": "waiting for auth token from DevOps",
  "blockerType": "people",
  "severity": "high",
  "status": "active",
  "suggestedActions": [
    "reach out to DevOps team",
    "escalate to Platform Lead"
  ],
  "conversationId": "conv789",
  "confidence": 0.90,
  "managerMarkedFalsePositive": false
}
```

### New Collection: Blocker Alerts

**Collection**: `users/{userId}/blockerAlerts/{alertId}`

**Document Structure**:
```typescript
{
  id: string;                    // auto-generated alert ID
  blockerId: string;             // reference to blocker document
  conversationId: string;        // reference to conversation
  severity: 'critical' | 'high'; // only critical/high get alerts
  blockerDescription: string;    // for notification text
  createdAt: Timestamp;
  read: boolean;                 // has manager seen this
  dismissed: boolean;            // has manager dismissed this
}
```

**Firestore Index Required**:
```json
{
  "collectionGroup": "blockerAlerts",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "read", "order": "ASCENDING"},
    {"fieldPath": "createdAt", "order": "DESCENDING"}
  ]
}
```

**Example Alert Document**:
```json
{
  "id": "alert123",
  "blockerId": "blocker789",
  "conversationId": "conv789",
  "severity": "high",
  "blockerDescription": "Sarah Chen blocked - waiting for auth token",
  "createdAt": "2025-10-24T10:00:05Z",
  "read": false,
  "dismissed": false
}
```

---

## Feature 3: Team Sentiment Analysis

### Message Document Extensions

**Collection**: `conversations/{conversationId}/messages/{messageId}`

**New Optional Fields**:

```typescript
// Sentiment score (simple)
sentimentScore?: number;  // -1.0 (very negative) to +1.0 (very positive)

// Detailed sentiment analysis
sentimentAnalysis?: {
  score: number;              // same as sentimentScore
  emotions: string[];         // e.g., ["frustrated", "stressed"]
  confidence: number;         // 0.0 to 1.0
  analyzedAt: Timestamp;
  reasoning: string;          // brief explanation
}
```

**Example Message with Sentiment**:
```json
{
  "id": "msg999",
  "text": "This is so frustrating, nothing works!",
  "senderId": "user123",
  "senderName": "Sarah Chen",
  
  "sentimentScore": -0.7,
  "sentimentAnalysis": {
    "score": -0.7,
    "emotions": ["frustrated", "stressed"],
    "confidence": 0.88,
    "analyzedAt": "2025-10-24T11:00:02Z",
    "reasoning": "Expresses frustration with work problems"
  }
}
```

### New Collection: User Daily Sentiment Aggregates

**Collection**: `sentimentTracking/userDaily/aggregates/{date_userId}`

**Document ID Format**: `2025-10-24_user123`

**Document Structure**:
```typescript
{
  userId: string;                        // user ID
  date: string;                          // yyyy-mm-dd
  averageSentiment: number;              // -1.0 to 1.0
  messageCount: number;                  // total messages analyzed
  emotionsDetected: {                    // emotion frequencies
    [emotion: string]: number;           // e.g., {"frustrated": 3, "happy": 1}
  };
  trend: 'improving' | 'stable' | 'declining';
  calculatedAt: Timestamp;
}
```

**Example**:
```json
{
  "userId": "user123",
  "date": "2025-10-24",
  "averageSentiment": -0.35,
  "messageCount": 12,
  "emotionsDetected": {
    "frustrated": 4,
    "stressed": 3,
    "neutral": 5
  },
  "trend": "declining",
  "calculatedAt": "2025-10-24T12:00:00Z"
}
```

### New Collection: Team Daily Sentiment Aggregates

**Collection**: `sentimentTracking/teamDaily/aggregates/{date_conversationId}`

**Document ID Format**: `2025-10-24_conv789`

**Document Structure**:
```typescript
{
  conversationId: string;                // conversation ID (group chat)
  date: string;                          // yyyy-mm-dd
  averageSentiment: number;              // team average -1.0 to 1.0
  memberSentiments: {                    // per-member sentiment
    [userId: string]: number;            // e.g., {"user123": -0.35, "user456": 0.62}
  };
  trend: 'improving' | 'stable' | 'declining';
  calculatedAt: Timestamp;
}
```

**Example**:
```json
{
  "conversationId": "conv789",
  "date": "2025-10-24",
  "averageSentiment": 0.18,
  "memberSentiments": {
    "user123": -0.35,
    "user456": 0.62,
    "user789": 0.28
  },
  "trend": "stable",
  "calculatedAt": "2025-10-24T12:00:00Z"
}
```

### New Collection: User Weekly Sentiment

**Collection**: `sentimentTracking/userWeekly/{userId}`

**Document Structure**:
```typescript
{
  userId: string;
  weekStartDate: string;                 // yyyy-mm-dd (Monday)
  dailyScores: {                         // scores for each day
    [date: string]: number;              // e.g., {"2025-10-21": 0.45, "2025-10-22": 0.32}
  };
  averageSentiment: number;              // week average
  trend: 'improving' | 'stable' | 'declining';
  calculatedAt: Timestamp;
}
```

### New Collection: Team Weekly Sentiment

**Collection**: `sentimentTracking/teamWeekly/{conversationId}`

**Document Structure**:
```typescript
{
  conversationId: string;
  weekStartDate: string;
  dailyScores: {
    [date: string]: number;
  };
  averageSentiment: number;
  trend: 'improving' | 'stable' | 'declining';
  calculatedAt: Timestamp;
}
```

---

## Firestore Security Rules Considerations

These schema extensions will require security rule updates:

```javascript
// Allow users to read their own blocker alerts
match /users/{userId}/blockerAlerts/{alertId} {
  allow read: if request.auth.uid == userId;
}

// Allow conversation participants to read blockers
match /conversations/{conversationId}/blockers/{blockerId} {
  allow read: if request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participantIds;
}

// Allow users to read sentiment aggregates for conversations they're in
match /sentimentTracking/teamDaily/aggregates/{docId} {
  allow read: if request.auth != null;  // further restrict based on conversation membership
}

match /sentimentTracking/userDaily/aggregates/{docId} {
  allow read: if request.auth != null;  // restrict to managers only
}
```

---

## Implementation Notes

1. **No Migration Required**: All new fields are optional, so existing messages continue to work
2. **Indexes**: Add the specified composite indexes to `firestore.indexes.json` before querying
3. **Cloud Functions**: Will handle all writes to these new fields/collections
4. **Client (Swift)**: Will only read from these fields, never write directly
5. **Cost Considerations**: Sentiment aggregates calculated hourly to minimize function executions

---

## Schema Version

**Version**: 2.0 (Advanced AI Features)
**Date**: 2025-10-24
**Author**: AI Assistant

This schema extends the existing MessageAI v1.0 schema without breaking changes.

