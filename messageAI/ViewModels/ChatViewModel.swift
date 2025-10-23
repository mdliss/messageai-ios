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
import FirebaseFunctions

/// Search result model
struct SearchResult: Identifiable {
    let id: String
    let messageId: String
    let text: String
    let senderName: String
    let timestamp: Date
    let score: Double
    let snippet: String
}

/// RAG search response model
struct RAGSearchResponse {
    let answer: String
    let sources: [SearchResult]
    let stats: SearchStats?
    let fallbackMode: String?
}

/// Search statistics
struct SearchStats {
    let totalMessages: Int
    let messagesWithEmbeddings: Int
    let embeddingLatency: Int
    let searchLatency: Int
    let llmLatency: Int
    let totalLatency: Int
}

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
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var searchAnswer: String? = nil  // NEW: RAG-generated answer
    @Published var searchStats: SearchStats? = nil  // NEW: Search statistics
    
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
        
        // Don't show cached messages immediately to avoid flash
        // Core Data will be used as backup if Firestore fails
        
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
                
                // Clean up Core Data: delete messages that no longer exist in Firestore
                let firestoreMessageIds = Set(fetchedMessages.map { $0.id })
                let coreDataMessages = self.coreDataService.fetchMessages(conversationId: conversationId)
                
                for coreDataMessage in coreDataMessages {
                    // If message exists in Core Data but not in Firestore, delete it
                    if !firestoreMessageIds.contains(coreDataMessage.id) {
                        print("🗑️ Deleting orphaned message from Core Data: \(coreDataMessage.id)")
                        self.coreDataService.deleteMessage(messageId: coreDataMessage.id)
                    }
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
    
    // MARK: - RAG Search
    
    /// Search messages using RAG (Retrieval-Augmented Generation)
    /// - Parameter query: Natural language search query
    func searchMessages(query: String) async {
        guard let conversationId = conversationId else {
            errorMessage = "No conversation selected"
            return
        }
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            searchAnswer = nil
            searchStats = nil
            return
        }
        
        isSearching = true
        searchResults = []
        searchAnswer = nil
        searchStats = nil
        
        print("🔍 Starting RAG search for: \"\(query)\"")
        
        // Check network status for fallback
        if !networkMonitor.isConnected {
            print("📡 Offline: Using keyword search fallback")
            performOfflineKeywordSearch(query: query)
            return
        }
        
        do {
            let functions = Functions.functions()
            let result = try await functions.httpsCallable("ragSearch").call([
                "conversationId": conversationId,
                "query": query,
                "limit": 10
            ])
            
            guard let data = result.data as? [String: Any] else {
                throw NSError(domain: "Search", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
            }
            
            // Parse answer
            if let answer = data["answer"] as? String {
                searchAnswer = answer
                print("💡 RAG Answer: \(answer)")
            }
            
            // Parse sources
            if let sourcesData = data["sources"] as? [[String: Any]] {
                let parsedResults = sourcesData.compactMap { sourceDict -> SearchResult? in
                    guard let messageId = sourceDict["messageId"] as? String,
                          let text = sourceDict["text"] as? String,
                          let senderName = sourceDict["senderName"] as? String,
                          let timestampStr = sourceDict["timestamp"] as? String,
                          let score = sourceDict["score"] as? Double,
                          let snippet = sourceDict["snippet"] as? String else {
                        return nil
                    }
                    
                    let formatter = ISO8601DateFormatter()
                    let timestamp = formatter.date(from: timestampStr) ?? Date()
                    
                    return SearchResult(
                        id: messageId,
                        messageId: messageId,
                        text: text,
                        senderName: senderName,
                        timestamp: timestamp,
                        score: score,
                        snippet: snippet
                    )
                }
                
                searchResults = parsedResults
                print("✅ Found \(parsedResults.count) source messages")
            }
            
            // Parse stats
            if let statsData = data["stats"] as? [String: Any],
               let totalMessages = statsData["totalMessages"] as? Int,
               let messagesWithEmbeddings = statsData["messagesWithEmbeddings"] as? Int,
               let embeddingLatency = statsData["embeddingLatency"] as? Int,
               let searchLatency = statsData["searchLatency"] as? Int,
               let llmLatency = statsData["llmLatency"] as? Int,
               let totalLatency = statsData["totalLatency"] as? Int {
                
                searchStats = SearchStats(
                    totalMessages: totalMessages,
                    messagesWithEmbeddings: messagesWithEmbeddings,
                    embeddingLatency: embeddingLatency,
                    searchLatency: searchLatency,
                    llmLatency: llmLatency,
                    totalLatency: totalLatency
                )
                
                print("📊 Search stats: Total \(totalLatency)ms (Embedding: \(embeddingLatency)ms, Search: \(searchLatency)ms, LLM: \(llmLatency)ms)")
                print("   Messages: \(messagesWithEmbeddings)/\(totalMessages) have embeddings")
            }
            
            // Check for fallback mode
            if let fallbackMode = data["fallbackMode"] as? String {
                print("⚠️ Search used fallback mode: \(fallbackMode)")
            }
            
            isSearching = false
            print("✅ RAG search complete")
            
        } catch {
            isSearching = false
            errorMessage = "Search failed: \(error.localizedDescription)"
            print("❌ RAG search failed: \(error.localizedDescription)")
            
            // Fallback to offline keyword search
            print("🔄 Falling back to offline keyword search...")
            performOfflineKeywordSearch(query: query)
        }
    }
    
    /// Perform offline keyword search as fallback
    /// - Parameter query: Search query
    private func performOfflineKeywordSearch(query: String) {
        guard let conversationId = conversationId else { return }
        
        let messages = coreDataService.searchMessages(query: query)
            .filter { $0.conversationId == conversationId }
        
        searchResults = messages.map { message in
            SearchResult(
                id: message.id,
                messageId: message.id,
                text: message.text,
                senderName: message.senderName,
                timestamp: message.createdAt,
                score: 0.5,  // Fixed score for keyword matches
                snippet: message.text.count > 100 ? String(message.text.prefix(100)) + "..." : message.text
            )
        }
        
        searchAnswer = "Found \(searchResults.count) keyword matches (offline mode)"
        isSearching = false
        
        print("✅ Offline keyword search complete: \(searchResults.count) results")
    }
    
    /// Clear search results
    func clearSearch() {
        searchResults = []
        searchAnswer = nil
        searchStats = nil
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
        searchResults = []
    }
    
    deinit {
        messageTask?.cancel()
        typingTask?.cancel()
        typingTimer?.invalidate()
    }
}

