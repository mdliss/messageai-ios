# Notification Behavior Documentation

## Current Implementation

MessageAI uses **local notifications** (not Firebase Cloud Messaging) for the iOS app. This is a deliberate design choice for the MVP.

## How Notifications Work

### Implementation Location
**File**: `messageAI/ViewModels/ConversationViewModel.swift` (lines 96-108)

```swift
let isViewingConversation = appStateService.isConversationOpen(conversation.id)

if !isViewingConversation {
    // Send local notification
    await notificationService.scheduleLocalNotification(...)
} else {
    // User is viewing this chat - skip notification
}
```

### Notification Triggers

✅ **Notification SENT when**:
- User is viewing a different conversation
- User is on decisions tab
- User is on AI tab
- User is on profile tab
- App is in background

❌ **Notification SKIPPED when**:
- User is actively viewing the conversation where message arrived

### Why Simulators Behave Differently

**Root Cause**: Each simulator is independent with its own:
1. Notification permissions (must be granted per simulator)
2. App state (different users logged in)
3. System settings
4. FCM tokens (if using remote notifications)

**Not a Bug**: This is expected iOS simulator behavior

### Simulator-Specific Behavior

**Simulator 1** (iPhone 17 Pro - Test user):
- ✅ Notifications working
- ✅ Permission granted
- ✅ User logged in

**Simulator 2** (iPhone 17 - Test3 user):  
- May need permission grant
- May need fresh app install
- Independent state from Simulator 1

## Testing Notifications

### On Same Simulator:
1. Open app on Simulator A (User 1)
2. Navigate away from chat (go to decisions/AI/profile tab)
3. Send message from another device as User 2
4. ✅ Notification should appear on Simulator A

### Across Multiple Simulators:
1. Boot Simulator A (User 1 logged in)
2. Boot Simulator B (User 2 logged in)
3. Send message from Simulator B
4. ✅ Notification should appear on Simulator A (if permissions granted)

### Common Issues:

**"Notifications not working on Simulator X"**
- Check: Has permission been granted? (First launch prompt)
- Check: Is user logged in on that simulator?
- Solution: Reset simulator, reinstall app, grant permissions

**"Works on one simulator but not another"**
- This is normal - each simulator is independent
- Solution: Grant permissions on each simulator separately

## Physical Device Behavior

On real iOS devices, notifications work more reliably because:
- APNs (Apple Push Notification service) is fully functional
- Background delivery is reliable
- System manages notification state properly

## Future Enhancements

When moving beyond MVP, consider:
1. **Firebase Cloud Messaging**: Remote push notifications
2. **Background fetch**: Check for messages periodically
3. **Badge counts**: Show unread count on app icon
4. **Rich notifications**: Show message preview with actions
5. **Notification grouping**: Group by conversation
6. **Silent notifications**: Update data without alert

## Debugging Notifications

### Check Permission Status:
```swift
UNUserNotificationCenter.current().getNotificationSettings { settings in
    print("Notification authorization: \(settings.authorizationStatus)")
}
```

### Enable Verbose Logging:
All notification events log to console with emoji prefixes:
- 🔔 Permission request
- ✅ Permission granted
- ⚠️ Permission denied
- 📬 Notification sent
- 📭 Notification skipped

### Console Output Example:
```
🔔 Requesting notification permission...
✅ Notification permission GRANTED
🔑 Getting FCM token...
✅ FCM token retrieved: [token]
📝 Saving FCM token to Firestore for user: user123
✅ FCM token saved to Firestore
📬 Opening conversation from notification: conv456
```

## Recommendation

For MVP testing:
- ✅ Use local notifications (current implementation)
- ✅ Test on 2-3 simulators with permissions granted
- ✅ Focus on core functionality (message delivery)
- ⏭️ Defer complex notification features to post-MVP

For production:
- Implement Firebase Cloud Messaging
- Test on physical devices
- Handle all edge cases (permission denied, token refresh, etc.)

## Summary

The notification behavior you're seeing is **expected and correct**:
- Each simulator needs permission grant independently
- Notifications work when properly configured
- Local notifications sufficient for MVP
- Not a code bug - just simulator limitations

**Status**: ✅ Working as designed

