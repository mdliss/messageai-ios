//
//  ConversationViewModel.swift
//  messageAI
//
//  Created by MessageAI Team
//  ViewModel managing conversation list
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

/// ViewModel managing conversation list and operations
@MainActor
class ConversationViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let firestoreService = FirestoreService.shared
    private let coreDataService = CoreDataService.shared
    private let notificationService = NotificationService.shared
    private let appStateService = AppStateService.shared
    private var conversationTask: Task<Void, Never>?
    private var messageListeners: [String: Task<Void, Never>] = [:]
    private var lastMessageTimestamps: [String: Date] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    /// Load conversations for current user
    func loadConversations(userId: String) {
        isLoading = true
        
        // Don't show cached conversations immediately to avoid flash
        // Core Data will be used as backup if Firestore fails
        
        // Subscribe to Firestore for real-time updates
        conversationTask = Task {
            for await fetchedConversations in firestoreService.getUserConversations(userId: userId) {
                self.conversations = fetchedConversations
                self.isLoading = false
                
                // Sync to Core Data
                for conversation in fetchedConversations {
                    self.coreDataService.saveConversation(conversation)
                }
                
                // Set up message listeners for notifications
                await self.setupMessageListeners(conversations: fetchedConversations, currentUserId: userId)
            }
        }
    }
    
    /// Set up message listeners for all conversations to trigger notifications
    /// - Parameters:
    ///   - conversations: List of conversations to monitor
    ///   - currentUserId: Current user ID
    private func setupMessageListeners(conversations: [Conversation], currentUserId: String) async {
        // Cancel old listeners for conversations that no longer exist
        let currentConvoIds = Set(conversations.map { $0.id })
        for (convoId, task) in messageListeners {
            if !currentConvoIds.contains(convoId) {
                task.cancel()
                messageListeners.removeValue(forKey: convoId)
            }
        }
        
        // Set up listeners for each conversation
        for conversation in conversations {
            guard messageListeners[conversation.id] == nil else { continue }
            
            let task = Task {
                for await messages in firestoreService.subscribeToMessages(conversationId: conversation.id) {
                    // Get the latest message
                    guard let latestMessage = messages.last else { continue }
                    
                    // Skip if message is from current user
                    guard latestMessage.senderId != currentUserId else { continue }
                    
                    // Skip if this is the first time we're seeing messages (initial load)
                    let lastTimestamp = lastMessageTimestamps[conversation.id]
                    if lastTimestamp == nil {
                        lastMessageTimestamps[conversation.id] = latestMessage.createdAt
                        continue
                    }
                    
                    // Skip if message is old (already seen)
                    guard latestMessage.createdAt > (lastTimestamp ?? Date.distantPast) else {
                        continue
                    }
                    
                    // Update last seen timestamp
                    lastMessageTimestamps[conversation.id] = latestMessage.createdAt
                    
                    // Check if user is currently viewing this conversation
                    let isViewingConversation = appStateService.isConversationOpen(conversation.id)
                    let isInForeground = appStateService.isAppInForeground
                    
                    // CRITICAL FIX: Show notifications when:
                    // - App is in background (always show), OR
                    // - App is in foreground but user is NOT viewing this specific conversation
                    // 
                    // This ensures notifications appear when:
                    // ✅ App in background
                    // ✅ App in foreground viewing different conversation
                    // ✅ App in foreground on different tab (Decisions, AI, Profile, Search)
                    // ❌ App in foreground viewing THIS conversation (user already sees it)
                    let shouldShowNotification = !isInForeground || !isViewingConversation
                    
                    // Enhanced logging to track notification decisions
                    print("📬 Message received in conversation: \(conversation.id)")
                    print("   → Sender: \(latestMessage.senderName)")
                    print("   → App state: \(isInForeground ? "FOREGROUND" : "BACKGROUND")")
                    print("   → Current conversation: \(appStateService.currentConversationId ?? "none")")
                    print("   → Viewing this conversation: \(isViewingConversation ? "YES" : "NO")")
                    print("   → Decision: \(shouldShowNotification ? "SHOW NOTIFICATION ✅" : "SKIP NOTIFICATION ❌")")
                    
                    if shouldShowNotification {
                        let reason: String
                        if !isInForeground {
                            reason = "app in background"
                        } else if !isViewingConversation {
                            reason = "user viewing different screen"
                        } else {
                            reason = "unknown"
                        }
                        print("🔔 Scheduling notification: \(reason)")
                        
                        await notificationService.scheduleLocalNotification(
                            title: latestMessage.senderName,
                            body: latestMessage.previewText,
                            conversationId: conversation.id
                        )
                    } else {
                        print("👁️ Skipping notification: user actively viewing this conversation")
                    }
                }
            }
            
            messageListeners[conversation.id] = task
        }
    }
    
    /// Create new direct conversation
    /// - Parameters:
    ///   - currentUserId: Current user ID
    ///   - otherUserId: Other user ID
    /// - Returns: Created conversation
    func createConversation(currentUserId: String, otherUserId: String) async throws -> Conversation {
        isLoading = true
        errorMessage = nil
        
        do {
            let conversation = try await firestoreService.createConversation(
                participantIds: [currentUserId, otherUserId],
                type: .direct
            )
            
            // Save to Core Data
            coreDataService.saveConversation(conversation)
            
            isLoading = false
            return conversation
        } catch {
            errorMessage = "Failed to create conversation: \(error.localizedDescription)"
            isLoading = false
            throw error
        }
    }
    
    /// Create new group conversation
    /// - Parameters:
    ///   - participantIds: Array of participant IDs
    ///   - groupName: Optional group name
    /// - Returns: Created conversation
    func createGroupConversation(participantIds: [String], groupName: String? = nil) async throws -> Conversation {
        isLoading = true
        errorMessage = nil
        
        do {
            let conversation = try await firestoreService.createGroupConversation(
                participantIds: participantIds,
                groupName: groupName
            )
            
            // Save to Core Data
            coreDataService.saveConversation(conversation)
            
            isLoading = false
            return conversation
        } catch {
            errorMessage = "Failed to create group: \(error.localizedDescription)"
            isLoading = false
            throw error
        }
    }
    
    /// Delete a conversation and all its messages
    /// - Parameter conversation: Conversation to delete
    func deleteConversation(_ conversation: Conversation) async {
        // Remove from local array immediately (optimistic UI)
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations.remove(at: index)
        }
        
        // Delete from Core Data
        coreDataService.deleteConversation(conversationId: conversation.id)
        
        // Delete from Firestore (includes all messages)
        do {
            try await firestoreService.deleteConversation(conversationId: conversation.id)
            print("✅ Conversation deleted successfully: \(conversation.id)")
        } catch {
            // Re-add conversation if deletion failed
            conversations.append(conversation)
            conversations.sort { $0.updatedAt > $1.updatedAt }
            
            errorMessage = "Failed to delete conversation: \(error.localizedDescription)"
            print("❌ Failed to delete conversation: \(error.localizedDescription)")
        }
    }
    
    /// Clean up subscriptions
    func cleanup() {
        conversationTask?.cancel()
        
        // Cancel all message listeners
        for (_, task) in messageListeners {
            task.cancel()
        }
        messageListeners.removeAll()
        lastMessageTimestamps.removeAll()
    }
    
    deinit {
        conversationTask?.cancel()
        
        // Cancel all message listeners
        for (_, task) in messageListeners {
            task.cancel()
        }
    }
}

