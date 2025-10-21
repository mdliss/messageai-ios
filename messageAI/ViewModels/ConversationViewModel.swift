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
    private var conversationTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    /// Load conversations for current user
    func loadConversations(userId: String) {
        isLoading = true
        
        // Load from Core Data first (fast)
        let cachedConversations = coreDataService.fetchConversations()
        if !cachedConversations.isEmpty {
            conversations = cachedConversations
            isLoading = false
        }
        
        // Subscribe to Firestore for real-time updates
        conversationTask = Task {
            for await fetchedConversations in firestoreService.getUserConversations(userId: userId) {
                self.conversations = fetchedConversations
                self.isLoading = false
                
                // Sync to Core Data
                for conversation in fetchedConversations {
                    self.coreDataService.saveConversation(conversation)
                }
            }
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
    }
    
    deinit {
        conversationTask?.cancel()
    }
}

