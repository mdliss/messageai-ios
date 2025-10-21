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
        let presenceRef = database.child("presence").child(userId)
        
        let data: [String: Any] = [
            "online": true,
            "lastSeen": ServerValue.timestamp()
        ]
        
        do {
            try await presenceRef.setValue(data)
            
            // Auto-set offline on disconnect
            let offlineData: [String: Any] = [
                "online": false,
                "lastSeen": ServerValue.timestamp()
            ]
            try await presenceRef.onDisconnectSetValue(offlineData)
            
            print("✅ User set online: \(userId)")
        } catch {
            print("❌ Failed to set user online: \(error.localizedDescription)")
        }
    }
    
    /// Set user offline status
    /// - Parameter userId: User ID
    func setUserOffline(userId: String) async {
        let presenceRef = database.child("presence").child(userId)
        
        let data: [String: Any] = [
            "online": false,
            "lastSeen": ServerValue.timestamp()
        ]
        
        do {
            try await presenceRef.setValue(data)
            print("✅ User set offline: \(userId)")
        } catch {
            print("❌ Failed to set user offline: \(error.localizedDescription)")
        }
    }
    
    /// Observe user presence
    /// - Parameter userId: User ID
    /// - Returns: AsyncStream of online status
    func observePresence(userId: String) -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let presenceRef = database.child("presence").child(userId)
            
            let handle = presenceRef.observe(.value) { snapshot in
                if let data = snapshot.value as? [String: Any],
                   let online = data["online"] as? Bool {
                    continuation.yield(online)
                } else {
                    continuation.yield(false)
                }
            }
            
            continuation.onTermination = { _ in
                presenceRef.removeObserver(withHandle: handle)
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

