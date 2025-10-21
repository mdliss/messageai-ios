//
//  RealtimeDBService.swift
//  messageAI
//
//  Created by MessageAI Team
//  Service for Firebase Realtime Database operations (typing, presence)
//

import Foundation
import FirebaseDatabase

/// Service managing Realtime Database operations
class RealtimeDBService {
    static let shared = RealtimeDBService()
    
    private let database: DatabaseReference
    
    private init() {
        self.database = FirebaseConfig.shared.realtimeDB
    }
    
    // MARK: - Typing Indicators
    
    /// Set typing status for a user in a conversation
    /// - Parameters:
    ///   - conversationId: Conversation ID
    ///   - userId: User ID
    ///   - isTyping: Typing status
    func setTyping(conversationId: String, userId: String, isTyping: Bool) async {
        let typingRef = database.child("typing").child(conversationId).child(userId)
        
        if isTyping {
            let data: [String: Any] = [
                "isTyping": true,
                "timestamp": ServerValue.timestamp()
            ]
            
            do {
                try await typingRef.setValue(data)
                
                // Auto-remove after 10 seconds
                try await typingRef.onDisconnectRemoveValue()
                
                print("✅ Set typing status: \(userId) in \(conversationId)")
            } catch {
                print("❌ Failed to set typing status: \(error.localizedDescription)")
            }
        } else {
            do {
                try await typingRef.removeValue()
                print("✅ Removed typing status: \(userId)")
            } catch {
                print("❌ Failed to remove typing status: \(error.localizedDescription)")
            }
        }
    }
    
    /// Observe typing status for a conversation
    /// - Parameter conversationId: Conversation ID
    /// - Returns: AsyncStream of typing user IDs
    func observeTyping(conversationId: String) -> AsyncStream<[String]> {
        AsyncStream { continuation in
            let typingRef = database.child("typing").child(conversationId)
            
            let handle = typingRef.observe(.value) { snapshot in
                var typingUsers: [String] = []
                
                for child in snapshot.children {
                    if let childSnapshot = child as? DataSnapshot,
                       let data = childSnapshot.value as? [String: Any],
                       let isTyping = data["isTyping"] as? Bool,
                       isTyping {
                        typingUsers.append(childSnapshot.key)
                    }
                }
                
                continuation.yield(typingUsers)
            }
            
            continuation.onTermination = { _ in
                typingRef.removeObserver(withHandle: handle)
            }
        }
    }
    
    // MARK: - Presence
    
    /// Set user online status
    /// - Parameter userId: User ID
    func setUserOnline(userId: String) async {
        print("🟢 Setting user ONLINE in Realtime DB: \(userId)")
        
        let presenceRef = database.child("presence").child(userId)
        
        let data: [String: Any] = [
            "online": true,
            "lastSeen": ServerValue.timestamp()
        ]
        
        do {
            // First, cancel any previous onDisconnect
            try await presenceRef.cancelDisconnectOperations()
            
            // Set online
            try await presenceRef.setValue(data)
            print("✅ User set to ONLINE in Realtime DB: \(userId)")
            print("   Path: presence/\(userId)")
            print("   Data written: \(data)")
            
            // Verify the write
            let snapshot = try await presenceRef.getData()
            if let verifyData = snapshot.value as? [String: Any] {
                print("✅ Verified data in Realtime DB: \(verifyData)")
            } else {
                print("⚠️ Could not verify data in Realtime DB")
            }
            
            // Auto-set offline on disconnect
            let offlineData: [String: Any] = [
                "online": false,
                "lastSeen": ServerValue.timestamp()
            ]
            try await presenceRef.onDisconnectSetValue(offlineData)
            print("✅ onDisconnect handler set for user: \(userId)")
            
        } catch {
            print("❌ Failed to set user online in Realtime DB: \(error.localizedDescription)")
            print("   Database URL: \(database.url)")
            print("   Error details: \(error)")
        }
    }
    
    /// Set user offline status
    /// - Parameter userId: User ID
    func setUserOffline(userId: String) async {
        print("🔴 Setting user OFFLINE in Realtime DB: \(userId)")
        
        let presenceRef = database.child("presence").child(userId)
        
        let data: [String: Any] = [
            "online": false,
            "lastSeen": ServerValue.timestamp()
        ]
        
        do {
            try await presenceRef.setValue(data)
            print("✅ User set to OFFLINE in Realtime DB: \(userId)")
        } catch {
            print("❌ Failed to set user offline in Realtime DB: \(error.localizedDescription)")
        }
    }
    
    /// Observe user presence
    /// - Parameter userId: User ID
    /// - Returns: AsyncStream of online status
    func observePresence(userId: String) -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let presenceRef = database.child("presence").child(userId)
            
            print("👀 Observing presence for user: \(userId)")
            
            let handle = presenceRef.observe(.value) { snapshot in
                if let data = snapshot.value as? [String: Any] {
                    // Firebase stores boolean as number: true = 1, false = 0
                    let online: Bool
                    if let boolValue = data["online"] as? Bool {
                        online = boolValue
                    } else if let intValue = data["online"] as? Int {
                        online = intValue == 1
                    } else if let numberValue = data["online"] as? NSNumber {
                        online = numberValue.boolValue
                    } else {
                        online = false
                    }
                    
                    print("📍 Presence update for \(userId): \(online)")
                    continuation.yield(online)
                } else {
                    print("📍 No presence data for \(userId), assuming offline")
                    continuation.yield(false)
                }
            }
            
            continuation.onTermination = { _ in
                presenceRef.removeObserver(withHandle: handle)
                print("🛑 Stopped observing presence for \(userId)")
            }
        }
    }
    
    /// Get user's last seen timestamp
    /// - Parameter userId: User ID
    /// - Returns: Last seen date or nil if never seen
    func getLastSeen(userId: String) async -> Date? {
        let presenceRef = database.child("presence").child(userId)
        
        do {
            let snapshot = try await presenceRef.getData()
            
            if let data = snapshot.value as? [String: Any],
               let lastSeenTimestamp = data["lastSeen"] as? Double {
                return Date(timeIntervalSince1970: lastSeenTimestamp / 1000)
            }
            
            return nil
        } catch {
            print("❌ Failed to get last seen: \(error.localizedDescription)")
            return nil
        }
    }
}

