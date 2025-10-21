//
//  NotificationService.swift
//  messageAI
//
//  Created by MessageAI Team
//  Service for push notification handling
//

import Foundation
import UIKit
import UserNotifications

/// Service managing push notifications
class NotificationService: NSObject {
    static let shared = NotificationService()
    
    var notificationPermissionGranted = false
    
    private let authService = AuthService.shared
    private var onNotificationTap: ((String) -> Void)?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Request Permission
    
    /// Request notification permissions
    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        
        print("🔔 Requesting notification permission...")
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            notificationPermissionGranted = granted
            
            if granted {
                print("✅ Notification permission GRANTED")
                setupNotificationCenter()
            } else {
                print("⚠️ Notification permission DENIED by user")
            }
        } catch {
            print("❌ Failed to request notification permission: \(error.localizedDescription)")
        }
    }
    
    /// Set up notification center delegate
    private func setupNotificationCenter() {
        // Set delegate for foreground notifications
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - Local Notifications

    /// Trigger a local notification for a new message
    /// - Parameters:
    ///   - senderName: Name of the message sender
    ///   - messageText: The message text
    ///   - conversationId: ID of the conversation for deep linking
    func triggerLocalNotification(senderName: String, messageText: String, conversationId: String) {
        print("📬 Triggering local notification for message from \(senderName)")

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = senderName
        content.body = messageText
        content.sound = .default
        content.userInfo = ["conversationId": conversationId]

        // Create trigger for immediate delivery
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        // Create request with unique identifier based on message content
        // Use conversationId + senderName + first few words of message to ensure uniqueness
        let messagePreview = messageText.prefix(20).replacingOccurrences(of: " ", with: "_")
        let uniqueId = "message-\(conversationId)-\(senderName)-\(messagePreview)"

        let request = UNNotificationRequest(
            identifier: uniqueId,
            content: content,
            trigger: trigger
        )

        // Add to notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule local notification: \(error.localizedDescription)")
            } else {
                print("✅ Local notification scheduled successfully")
            }
        }
    }
    
    // MARK: - Handle Notification Tap
    
    /// Set handler for notification tap
    /// - Parameter handler: Handler called with conversation ID
    func setNotificationTapHandler(_ handler: @escaping (String) -> Void) {
        onNotificationTap = handler
    }
    
    /// Handle notification data
    /// - Parameter userInfo: Notification payload
    func handleNotificationData(_ userInfo: [AnyHashable: Any]) {
        if let conversationId = userInfo["conversationId"] as? String {
            print("📬 Opening conversation from notification: \(conversationId)")
            Task { @MainActor in
                onNotificationTap?(conversationId)
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    
    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo

        print("📬 Presenting notification in FOREGROUND")
        print("   ID: \(notification.request.identifier)")
        print("   Title: \(notification.request.content.title)")
        print("   Body: \(notification.request.content.body)")
        print("   UserInfo: \(userInfo)")

        // Show banner, badge, and play sound
        completionHandler([.banner, .badge, .sound])
    }
    
    /// Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        print("📬 User tapped notification")
        
        Task { @MainActor in
            handleNotificationData(userInfo)
        }
        
        completionHandler()
    }
}


