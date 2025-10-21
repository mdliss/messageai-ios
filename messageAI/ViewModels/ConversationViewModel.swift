//
//  ConversationViewModel.swift
//  messageAI
//
//  Created by MessageAI Team
//  ViewModel managing conversation list
//

import Foundation
import Combine

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
    
    /// Clean up subscriptions
    func cleanup() {
        conversationTask?.cancel()
    }
    
    deinit {
        conversationTask?.cancel()
    }
}

