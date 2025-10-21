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
import FirebaseMessaging

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
                await registerForRemoteNotifications()
            } else {
                print("⚠️ Notification permission DENIED by user")
            }
        } catch {
            print("❌ Failed to request notification permission: \(error.localizedDescription)")
        }
    }
    
    /// Register for remote notifications
    private func registerForRemoteNotifications() async {
        await UIApplication.shared.registerForRemoteNotifications()
        
        // Set delegate for foreground notifications
        UNUserNotificationCenter.current().delegate = self
        
        // Set Firebase Messaging delegate
        Messaging.messaging().delegate = self
    }
    
    // MARK: - FCM Token
    
    /// Get FCM token and save to Firestore
    func getFCMToken() async {
        print("🔑 Getting FCM token...")
        
        do {
            let token = try await Messaging.messaging().token()
            print("✅ FCM token retrieved: \(token)")
            
            // Save to Firestore
            if let userId = authService.currentUserId {
                print("📝 Saving FCM token to Firestore for user: \(userId)")
                try await authService.updateFCMToken(userId: userId, token: token)
                print("✅ FCM token saved to Firestore")
            } else {
                print("⚠️ No user ID - cannot save FCM token")
            }
        } catch {
            print("❌ Failed to get FCM token: \(error.localizedDescription)")
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
        
        print("📬 Received notification in FOREGROUND")
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

// MARK: - MessagingDelegate

extension NotificationService: MessagingDelegate {
    
    /// Handle FCM token refresh
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        
        print("✅ FCM token refreshed: \(token)")
        
        Task {
            // Save to Firestore
            if let userId = authService.currentUserId {
                try? await authService.updateFCMToken(userId: userId, token: token)
            }
        }
    }
}

