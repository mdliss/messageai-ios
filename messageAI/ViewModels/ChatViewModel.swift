//
//  ChatViewModel.swift
//  messageAI
//
//  Created by MessageAI Team
//  ViewModel managing chat messages and real-time updates
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

/// ViewModel managing chat functionality
@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSending = false
    @Published var isUploadingImage = false
    @Published var typingUsers: [String] = []
    @Published var typingUserNames: [String: String] = [:]
    @Published var isLoadingOlderMessages = false
    @Published var hasMoreMessages = true
    
    private let firestoreService = FirestoreService.shared
    private let coreDataService = CoreDataService.shared
    private let storageService = StorageService.shared
    private let realtimeDBService = RealtimeDBService.shared
    private let syncService = SyncService.shared
    private let networkMonitor = NetworkMonitor.shared
    private var messageTask: Task<Void, Never>?
    private var typingTask: Task<Void, Never>?
    private var typingTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private var conversationId: String?
    private var currentUserId: String?
    
    // MARK: - Load Messages
    
    /// Load messages for a conversation
    /// - Parameters:
    ///   - conversationId: Conversation ID
    ///   - currentUserId: Current user ID
    func loadMessages(conversationId: String, currentUserId: String) {
        self.conversationId = conversationId
        self.currentUserId = currentUserId
        
        isLoading = true
        
        // Load from Core Data first (fast initial load)
        let cachedMessages = coreDataService.fetchMessages(conversationId: conversationId)
        if !cachedMessages.isEmpty {
            messages = cachedMessages
            isLoading = false
        }
        
        // Subscribe to Firestore for real-time updates (only recent 50 messages)
        messageTask = Task {
            for await fetchedMessages in firestoreService.subscribeToMessages(conversationId: conversationId, limit: 50) {
                self.messages = fetchedMessages
                self.isLoading = false
                
                // Check if there might be more messages
                self.hasMoreMessages = fetchedMessages.count >= 50
                
                // Sync to Core Data in background
                for message in fetchedMessages {
                    self.coreDataService.saveMessage(message)
                }
                
                // Update conversation's last message
                if let lastMessage = fetchedMessages.last {
                    self.updateConversationLastMessage(lastMessage)
                }
                
                // Mark messages as read
                await self.markMessagesAsRead(fetchedMessages, currentUserId: currentUserId)
            }
        }
        
        // Subscribe to typing indicators
        subscribeToTyping(conversationId: conversationId, currentUserId: currentUserId)
        
        // Listen for network reconnection to refresh messages
        setupNetworkReconnectionListener()
    }
    
    // MARK: - Load Older Messages
    
    /// Load older messages for backfilling when scrolling up
    func loadOlderMessages() async {
        guard let conversationId = conversationId else { return }
        guard !isLoadingOlderMessages else { return }
        guard hasMoreMessages else { 
            print("ℹ️ No more messages to load")
            return 
        }
        
        // Get the oldest message timestamp
        guard let oldestMessage = messages.first else { return }
        
        isLoadingOlderMessages = true
        print("📜 Loading older messages before \(oldestMessage.createdAt)...")
        
        do {
            let olderMessages = try await firestoreService.fetchOlderMessages(
                conversationId: conversationId,
                beforeTimestamp: oldestMessage.createdAt,
                limit: 50
            )
            
            if olderMessages.isEmpty {
                hasMoreMessages = false
                print("ℹ️ No more older messages available")
            } else {
                // Prepend older messages to the beginning
                messages.insert(contentsOf: olderMessages, at: 0)
                
                // Save to Core Data
                for message in olderMessages {
                    coreDataService.saveMessage(message)
                }
                
                print("✅ Loaded \(olderMessages.count) older messages")
            }
        } catch {
            print("❌ Failed to load older messages: \(error.localizedDescription)")
        }
        
        isLoadingOlderMessages = false
    }
    
    /// Set up listener for network reconnection to refresh messages
    private func setupNetworkReconnectionListener() {
        NotificationCenter.default.publisher(for: .networkConnected)
            .sink { [weak self] _ in
                guard let self = self, let conversationId = self.conversationId else { return }
                
                Task {
                    print("🔄 Network reconnected, refreshing messages...")
                    
                    // Reload messages from Core Data to show updated sync status
                    let updatedMessages = self.coreDataService.fetchMessages(conversationId: conversationId)
                    await MainActor.run {
                        self.messages = updatedMessages
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Typing Indicators
    
    /// Subscribe to typing indicators
    private func subscribeToTyping(conversationId: String, currentUserId: String) {
        typingTask = Task {
            for await typingUserIds in realtimeDBService.observeTyping(conversationId: conversationId) {
                // Filter out current user
                let otherUsersTyping = typingUserIds.filter { $0 != currentUserId }
                self.typingUsers = otherUsersTyping
                print("⌨️ Typing users: \(otherUsersTyping)")
            }
        }
    }
    
    /// Update typing status
    /// - Parameter isTyping: Whether user is typing
    func updateTypingStatus(isTyping: Bool, currentUserId: String) {
        guard let conversationId = conversationId else { return }
        
        Task {
            await realtimeDBService.setTyping(
                conversationId: conversationId,
                userId: currentUserId,
                isTyping: isTyping
            )
        }
    }
    
    /// Handle text input change (debounced)
    func handleTextChange(_ text: String, currentUserId: String) {
        guard let conversationId = conversationId else { return }
        
        // Cancel previous timer
        typingTimer?.invalidate()
        
        if !text.isEmpty {
            // Set typing to true
            Task {
                await realtimeDBService.setTyping(
                    conversationId: conversationId,
                    userId: currentUserId,
                    isTyping: true
                )
            }
            
            // Set timer to clear typing after 3 seconds of inactivity
            typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                Task {
                    await self?.realtimeDBService.setTyping(
                        conversationId: conversationId,
                        userId: currentUserId,
                        isTyping: false
                    )
                }
            }
        } else {
            // Clear typing immediately if text is empty
            Task {
                await realtimeDBService.setTyping(
                    conversationId: conversationId,
                    userId: currentUserId,
                    isTyping: false
                )
            }
        }
    }
    
    // MARK: - Send Message
    
    /// Send text message with optimistic UI and offline support
    /// - Parameters:
    ///   - text: Message text
    ///   - senderId: Sender ID
    ///   - senderName: Sender name
    ///   - senderPhotoURL: Sender photo URL
    func sendMessage(text: String, senderId: String, senderName: String, senderPhotoURL: String? = nil) async {
        guard let conversationId = conversationId else {
            errorMessage = "No conversation selected"
            return
        }
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isSending = true
        
        // Generate local ID for optimistic UI
        let localId = UUID().uuidString
        
        // Create message with temporary ID
        let message = Message(
            id: localId,
            conversationId: conversationId,
            senderId: senderId,
            senderName: senderName,
            senderPhotoURL: senderPhotoURL,
            type: .text,
            text: text,
            createdAt: Date(),
            status: .sending,
            localId: localId,
            isSynced: false
        )
        
        // Optimistic UI - add message immediately
        messages.append(message)
        
        // Save to Core Data immediately (offline support)
        coreDataService.saveMessage(message)
        print("💾 Message saved to Core Data: \(localId)")
        
        // Check if we're online
        if !networkMonitor.isConnected {
            print("📡 Offline: Message queued for sync when connected")
            isSending = false
            return
        }
        
        // Try to upload to Firestore if online
        do {
            let serverId = try await firestoreService.sendMessage(message, to: conversationId)
            
            // Update message with server ID
            if let index = messages.firstIndex(where: { $0.localId == localId }) {
                var updatedMessage = messages[index]
                updatedMessage.id = serverId
                updatedMessage.status = .sent
                updatedMessage.isSynced = true
                messages[index] = updatedMessage
                
                // Update Core Data
                coreDataService.updateMessageSync(localId: localId, serverId: serverId)
            }
            
            print("✅ Message sent successfully: \(serverId)")
        } catch {
            // Keep as "sending" status - will retry via SyncService
            print("⚠️ Failed to send message, will retry via sync: \(error.localizedDescription)")
            
            // Update sync service pending count
            syncService.updatePendingCount()
        }
        
        isSending = false
    }
    
    // MARK: - Send Image Message
    
    /// Send image message with optimistic UI and offline support
    /// - Parameters:
    ///   - image: UIImage to send
    ///   - caption: Optional caption text
    ///   - senderId: Sender ID
    ///   - senderName: Sender name
    ///   - senderPhotoURL: Sender photo URL
    func sendImageMessage(image: UIImage, caption: String = "", senderId: String, senderName: String, senderPhotoURL: String? = nil) async {
        guard let conversationId = conversationId else {
            errorMessage = "No conversation selected"
            return
        }
        
        isUploadingImage = true
        
        // Compress image
        guard let compressedImage = ImageCompressor.compressAndResize(image) else {
            errorMessage = "Failed to compress image"
            isUploadingImage = false
            return
        }
        
        // Generate local ID
        let localId = UUID().uuidString
        
        // Check if we're offline - can't upload images offline
        if !networkMonitor.isConnected {
            errorMessage = "Cannot send images while offline. Please reconnect and try again"
            print("📡 Offline: Cannot upload image")
            isUploadingImage = false
            return
        }
        
        do {
            // Upload image to Storage
            let imageURL = try await storageService.uploadMessageImage(compressedImage, conversationId: conversationId)
            
            // Create message
            let message = Message(
                id: localId,
                conversationId: conversationId,
                senderId: senderId,
                senderName: senderName,
                senderPhotoURL: senderPhotoURL,
                type: .image,
                text: caption,
                imageURL: imageURL,
                createdAt: Date(),
                status: .sending,
                localId: localId,
                isSynced: false
            )
            
            // Optimistic UI - add message immediately
            messages.append(message)
            
            // Save to Core Data
            coreDataService.saveMessage(message)
            print("💾 Image message saved to Core Data: \(localId)")
            
            // Upload to Firestore
            let serverId = try await firestoreService.sendMessage(message, to: conversationId)
            
            // Update message with server ID
            if let index = messages.firstIndex(where: { $0.localId == localId }) {
                messages[index].id = serverId
                messages[index].status = .sent
                messages[index].isSynced = true
                
                // Update Core Data
                coreDataService.updateMessageSync(localId: localId, serverId: serverId)
            }
            
            print("✅ Image message sent successfully: \(serverId)")
        } catch {
            // Keep as "sending" for retry
            print("⚠️ Failed to send image message, will retry via sync: \(error.localizedDescription)")
            
            // Update sync service pending count
            syncService.updatePendingCount()
        }
        
        isUploadingImage = false
    }
    
    // MARK: - Mark Messages as Read
    
    /// Mark visible messages as read
    /// - Parameters:
    ///   - messages: Array of messages
    ///   - currentUserId: Current user ID
    private func markMessagesAsRead(_ messages: [Message], currentUserId: String) async {
        guard let conversationId = conversationId else { return }
        
        // Find unread messages from others
        let unreadMessageIds = messages
            .filter { !$0.isFromCurrentUser(userId: currentUserId) && !$0.readBy.contains(currentUserId) }
            .map { $0.id }
        
        guard !unreadMessageIds.isEmpty else { return }
        
        // Mark as read in Firestore
        do {
            try await firestoreService.markMessagesAsRead(
                conversationId: conversationId,
                messageIds: unreadMessageIds,
                userId: currentUserId
            )
            print("✅ Marked \(unreadMessageIds.count) messages as read")
        } catch {
            print("❌ Failed to mark messages as read: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Update Conversation
    
    /// Update conversation's last message
    /// - Parameter message: Last message
    private func updateConversationLastMessage(_ message: Message) {
        guard let conversationId = conversationId else { return }
        
        let lastMessage = LastMessage(
            text: message.previewText,
            senderId: message.senderId,
            timestamp: message.createdAt
        )
        
        coreDataService.updateConversationLastMessage(
            conversationId: conversationId,
            lastMessage: lastMessage
        )
    }
    
    // MARK: - Retry Failed Message
    
    /// Retry sending a failed message
    /// - Parameter message: Failed message
    func retryMessage(_ message: Message) async {
        guard message.status == .failed else { return }
        
        // Update status to sending
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index].status = .sending
        }
        
        // Retry upload
        do {
            let serverId = try await firestoreService.sendMessage(message, to: message.conversationId)
            
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index].id = serverId
                messages[index].status = .sent
                messages[index].isSynced = true
                
                if let localId = message.localId {
                    coreDataService.updateMessageSync(localId: localId, serverId: serverId)
                }
            }
            
            print("✅ Message retry successful: \(serverId)")
        } catch {
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index].status = .failed
            }
            errorMessage = "Retry failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Delete Message
    
    /// Delete a message
    /// - Parameters:
    ///   - message: Message to delete
    ///   - currentUserId: Current user ID (only owner can delete)
    func deleteMessage(_ message: Message, currentUserId: String) async {
        // Only allow deleting own messages
        guard message.senderId == currentUserId else {
            errorMessage = "You can only delete your own messages"
            print("❌ Cannot delete message: not the sender")
            return
        }
        
        guard let conversationId = conversationId else {
            errorMessage = "No conversation selected"
            return
        }
        
        // Remove from local array immediately (optimistic UI)
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages.remove(at: index)
        }
        
        // Delete from Core Data
        coreDataService.deleteMessage(messageId: message.id)
        
        // Delete from Firestore
        do {
            try await firestoreService.deleteMessage(messageId: message.id, conversationId: conversationId)
            
            // Delete image from storage if exists
            if let imageURL = message.imageURL, !imageURL.isEmpty {
                try? await storageService.deleteImageByURL(imageURL)
            }
            
            print("✅ Message deleted successfully: \(message.id)")
        } catch {
            // Re-add message if deletion failed
            messages.append(message)
            messages.sort { $0.createdAt < $1.createdAt }
            
            errorMessage = "Failed to delete message: \(error.localizedDescription)"
            print("❌ Failed to delete message: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cleanup
    
    /// Clean up subscriptions
    func cleanup() {
        messageTask?.cancel()
        typingTask?.cancel()
        typingTimer?.invalidate()
        
        // Clear typing status
        if let conversationId = conversationId, let currentUserId = currentUserId {
            Task {
                await realtimeDBService.setTyping(
                    conversationId: conversationId,
                    userId: currentUserId,
                    isTyping: false
                )
            }
        }
        
        conversationId = nil
        currentUserId = nil
        messages = []
        typingUsers = []
    }
    
    deinit {
        messageTask?.cancel()
        typingTask?.cancel()
        typingTimer?.invalidate()
    }
}

