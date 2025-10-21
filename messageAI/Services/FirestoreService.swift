//
//  FirestoreService.swift
//  messageAI
//
//  Created by MessageAI Team
//  Firestore database service for all database operations
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Service managing all Firestore operations
class FirestoreService {
    static let shared = FirestoreService()
    
    private let db: Firestore
    private let auth: Auth
    
    private init() {
        self.db = FirebaseConfig.shared.db
        self.auth = FirebaseConfig.shared.auth
    }
    
    // MARK: - User Operations
    
    /// Create user profile in Firestore
    /// - Parameter user: User to create
    func createUserProfile(_ user: User) async throws {
        let userRef = db.collection("users").document(user.id)
        try await userRef.setData(user.toDictionary())
        print("✅ User profile created: \(user.id)")
    }
    
    /// Get user from Firestore
    /// - Parameter userId: User ID
    /// - Returns: User object
    func getUser(_ userId: String) async throws -> User {
        let userRef = db.collection("users").document(userId)
        let document = try await userRef.getDocument()
        
        guard document.exists else {
            throw FirestoreError.documentNotFound
        }
        
        let user = try document.data(as: User.self)
        return user
    }
    
    /// Get multiple users
    /// - Parameter userIds: Array of user IDs
    /// - Returns: Array of users
    func getUsers(_ userIds: [String]) async throws -> [User] {
        var users: [User] = []
        
        for userId in userIds {
            do {
                let user = try await getUser(userId)
                users.append(user)
            } catch {
                print("⚠️ Failed to fetch user \(userId): \(error.localizedDescription)")
            }
        }
        
        return users
    }
    
    /// Get all users (for user picker)
    /// - Returns: Array of all users
    func getAllUsers() async throws -> [User] {
        let usersRef = db.collection("users")
        let snapshot = try await usersRef.getDocuments()
        
        let users = snapshot.documents.compactMap { document -> User? in
            try? document.data(as: User.self)
        }
        
        return users
    }
    
    /// Update user online status
    /// - Parameters:
    ///   - userId: User ID
    ///   - isOnline: Online status
    func updateUserOnlineStatus(_ userId: String, isOnline: Bool) async throws {
        let userRef = db.collection("users").document(userId)
        try await userRef.updateData([
            "isOnline": isOnline,
            "lastSeen": Date()
        ])
        print("✅ User online status updated: \(userId) → \(isOnline)")
    }
    
    // MARK: - Conversation Operations
    
    /// Get user's conversations as AsyncStream for real-time updates
    /// - Parameter userId: User ID
    /// - Returns: AsyncStream of conversations
    func getUserConversations(userId: String) -> AsyncStream<[Conversation]> {
        AsyncStream { continuation in
            let conversationsRef = db.collection("conversations")
                .whereField("participantIds", arrayContains: userId)
            
            let listener = conversationsRef.addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error fetching conversations: \(error.localizedDescription)")
                    continuation.finish()
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    continuation.yield([])
                    return
                }
                
                let conversations = documents.compactMap { document -> Conversation? in
                    try? document.data(as: Conversation.self)
                }
                
                // Sort by updatedAt descending (most recent first)
                let sortedConversations = conversations.sorted { $0.updatedAt > $1.updatedAt }
                
                continuation.yield(sortedConversations)
                print("✅ Fetched \(sortedConversations.count) conversations")
            }
            
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }
    
    /// Create direct conversation
    /// - Parameters:
    ///   - participantIds: Array of participant IDs (must be 2)
    ///   - type: Conversation type
    /// - Returns: Created conversation
    func createConversation(participantIds: [String], type: ConversationType = .direct) async throws -> Conversation {
        // Check if conversation already exists for direct chats
        if type == .direct && participantIds.count == 2 {
            let existingConvo = try await findExistingDirectConversation(participantIds: participantIds)
            if let existingConvo = existingConvo {
                print("ℹ️ Conversation already exists: \(existingConvo.id)")
                return existingConvo
            }
        }
        
        // Get participant details
        let users = try await getUsers(participantIds)
        var participantDetails: [String: ParticipantDetail] = [:]
        
        for user in users {
            participantDetails[user.id] = ParticipantDetail(
                displayName: user.displayName,
                photoURL: user.photoURL
            )
        }
        
        // Create new conversation
        let conversation = Conversation(
            type: type,
            participantIds: participantIds,
            participantDetails: participantDetails
        )
        
        let conversationRef = db.collection("conversations").document(conversation.id)
        try await conversationRef.setData(conversation.toDictionary())
        
        print("✅ Conversation created: \(conversation.id)")
        return conversation
    }
    
    /// Create group conversation
    /// - Parameters:
    ///   - participantIds: Array of participant IDs (3+)
    ///   - groupName: Optional group name
    /// - Returns: Created conversation
    func createGroupConversation(participantIds: [String], groupName: String? = nil) async throws -> Conversation {
        guard participantIds.count >= 3 else {
            throw FirestoreError.invalidGroupSize
        }
        
        // Get participant details
        let users = try await getUsers(participantIds)
        var participantDetails: [String: ParticipantDetail] = [:]
        
        for user in users {
            participantDetails[user.id] = ParticipantDetail(
                displayName: user.displayName,
                photoURL: user.photoURL
            )
        }
        
        // Create group conversation
        let conversation = Conversation(
            type: .group,
            participantIds: participantIds,
            participantDetails: participantDetails,
            groupName: groupName
        )
        
        let conversationRef = db.collection("conversations").document(conversation.id)
        try await conversationRef.setData(conversation.toDictionary())
        
        print("✅ Group conversation created: \(conversation.id)")
        return conversation
    }
    
    /// Find existing direct conversation between two users
    /// - Parameter participantIds: Array of two participant IDs
    /// - Returns: Existing conversation if found
    private func findExistingDirectConversation(participantIds: [String]) async throws -> Conversation? {
        let conversationsRef = db.collection("conversations")
            .whereField("type", isEqualTo: "direct")
            .whereField("participantIds", arrayContains: participantIds[0])
        
        let snapshot = try await conversationsRef.getDocuments()
        
        for document in snapshot.documents {
            if let conversation = try? document.data(as: Conversation.self),
               Set(conversation.participantIds) == Set(participantIds) {
                return conversation
            }
        }
        
        return nil
    }
    
    /// Get specific conversation
    /// - Parameter conversationId: Conversation ID
    /// - Returns: Conversation
    func getConversation(_ conversationId: String) async throws -> Conversation {
        let conversationRef = db.collection("conversations").document(conversationId)
        let document = try await conversationRef.getDocument()
        
        guard document.exists else {
            throw FirestoreError.documentNotFound
        }
        
        let conversation = try document.data(as: Conversation.self)
        return conversation
    }
    
    /// Delete conversation and all its messages
    /// - Parameter conversationId: Conversation ID to delete
    func deleteConversation(conversationId: String) async throws {
        let conversationRef = db.collection("conversations").document(conversationId)
        
        // Delete all messages in the conversation first
        let messagesRef = conversationRef.collection("messages")
        let messagesSnapshot = try await messagesRef.getDocuments()
        
        // Batch delete messages (max 500 per batch)
        var batch = db.batch()
        var operationCount = 0
        let messageCount = messagesSnapshot.documents.count
        
        for document in messagesSnapshot.documents {
            batch.deleteDocument(document.reference)
            operationCount += 1
            
            // Commit batch if we hit 500 operations and create new batch
            if operationCount == 500 {
                try await batch.commit()
                batch = db.batch()
                operationCount = 0
            }
        }
        
        // Commit remaining message deletions
        if operationCount > 0 {
            try await batch.commit()
        }
        
        // Delete the conversation document
        try await conversationRef.delete()
        
        print("✅ Deleted conversation and \(messageCount) messages: \(conversationId)")
    }
    
    // MARK: - Message Operations
    
    /// Subscribe to messages in a conversation (real-time)
    /// - Parameter conversationId: Conversation ID
    /// - Returns: AsyncStream of messages
    func subscribeToMessages(conversationId: String) -> AsyncStream<[Message]> {
        AsyncStream { continuation in
            let messagesRef = db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .order(by: "createdAt")
            
            let listener = messagesRef.addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error fetching messages: \(error.localizedDescription)")
                    continuation.finish()
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    continuation.yield([])
                    return
                }
                
                let messages = documents.compactMap { document -> Message? in
                    try? document.data(as: Message.self)
                }
                
                continuation.yield(messages)
                print("✅ Fetched \(messages.count) messages for conversation \(conversationId)")
            }
            
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }
    
    /// Send message to conversation
    /// - Parameters:
    ///   - message: Message to send
    ///   - conversationId: Conversation ID
    /// - Returns: Server-assigned message ID
    @discardableResult
    func sendMessage(_ message: Message, to conversationId: String) async throws -> String {
        let conversationRef = db.collection("conversations").document(conversationId)
        let messagesRef = conversationRef.collection("messages")
        
        // Create message document
        let messageRef = messagesRef.document()
        var messageData = message.toDictionary()
        messageData["id"] = messageRef.documentID
        
        try await messageRef.setData(messageData)
        
        // Update conversation's last message
        let lastMessage = LastMessage(
            text: message.previewText,
            senderId: message.senderId,
            timestamp: message.createdAt
        )
        
        try await conversationRef.updateData([
            "lastMessage": lastMessage.toDictionary(),
            "updatedAt": message.createdAt
        ])
        
        print("✅ Message sent: \(messageRef.documentID)")
        return messageRef.documentID
    }
    
    /// Update message status
    /// - Parameters:
    ///   - messageId: Message ID
    ///   - conversationId: Conversation ID
    ///   - status: New status
    func updateMessageStatus(messageId: String, conversationId: String, status: MessageStatus) async throws {
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
        
        try await messageRef.updateData([
            "status": status.rawValue
        ])
        
        print("✅ Message status updated: \(messageId) → \(status.rawValue)")
    }
    
    /// Delete message from Firestore
    /// - Parameters:
    ///   - messageId: Message ID to delete
    ///   - conversationId: Conversation ID
    func deleteMessage(messageId: String, conversationId: String) async throws {
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
        
        try await messageRef.delete()
        print("✅ Message deleted from Firestore: \(messageId)")
    }
    
    /// Mark messages as read
    /// - Parameters:
    ///   - conversationId: Conversation ID
    ///   - messageIds: Array of message IDs to mark as read
    ///   - userId: User ID who read the messages
    func markMessagesAsRead(conversationId: String, messageIds: [String], userId: String) async throws {
        let batch = db.batch()
        
        for messageId in messageIds {
            let messageRef = db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .document(messageId)
            
            batch.updateData([
                "readBy": FieldValue.arrayUnion([userId]),
                "status": MessageStatus.read.rawValue
            ], forDocument: messageRef)
        }
        
        try await batch.commit()
        print("✅ Marked \(messageIds.count) messages as read")
    }
}

// MARK: - Firestore Errors

enum FirestoreError: LocalizedError {
    case documentNotFound
    case invalidData
    case invalidGroupSize
    
    var errorDescription: String? {
        switch self {
        case .documentNotFound:
            return "Document not found"
        case .invalidData:
            return "Invalid data format"
        case .invalidGroupSize:
            return "Group must have at least 3 participants"
        }
    }
}

