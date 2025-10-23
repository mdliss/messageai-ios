//
//  PriorityFilterViewModel.swift
//  messageAI
//
//  Created by MessageAI Team
//  ViewModel for priority filter view
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
class PriorityFilterViewModel: ObservableObject {
    @Published var allPriorityMessages: [PriorityMessage] = []
    @Published var isLoading = false
    @Published var conversationNames: [String: String] = [:]
    
    private let db = FirebaseConfig.shared.db
    private var listeners: [ListenerRegistration] = []
    
    /// All urgent messages
    var urgentMessages: [PriorityMessage] {
        allPriorityMessages.filter { $0.message.priority == .urgent }
    }
    
    /// All high priority messages
    var highPriorityMessages: [PriorityMessage] {
        allPriorityMessages.filter { $0.message.priority == .high }
    }
    
    // MARK: - Load Priority Messages
    
    /// Load all priority messages across user's conversations
    /// - Parameter userId: Current user ID
    func loadPriorityMessages(userId: String) {
        isLoading = true
        
        Task {
            do {
                // Get all conversations for user
                let conversationsRef = db.collection("conversations")
                    .whereField("participantIds", arrayContains: userId)
                
                let conversationsSnapshot = try await conversationsRef.getDocuments()
                
                print("🔍 Loading priority messages from \(conversationsSnapshot.documents.count) conversations")
                
                // Set up real-time listeners for priority messages in each conversation
                for conversationDoc in conversationsSnapshot.documents {
                    let conversationId = conversationDoc.documentID
                    let conversationData = try? conversationDoc.data(as: Conversation.self)
                    
                    // Store conversation name for display
                    if let conversation = conversationData {
                        conversationNames[conversationId] = conversation.displayName(for: userId)
                    }
                    
                    // Listen to priority messages in this conversation
                    let messagesRef = conversationDoc.reference
                        .collection("messages")
                        .whereField("type", isEqualTo: "text")
                        .order(by: "createdAt", descending: true)
                        .limit(to: 100)
                    
                    let listener = messagesRef.addSnapshotListener { [weak self] snapshot, error in
                        guard let self = self else { return }
                        
                        if let error = error {
                            print("❌ Error listening to messages: \(error.localizedDescription)")
                            return
                        }
                        
                        guard let documents = snapshot?.documents else { return }
                        
                        // Parse messages and filter for priority
                        let messages = documents.compactMap { doc -> Message? in
                            try? doc.data(as: Message.self)
                        }.filter { message in
                            // Only show urgent or high priority
                            message.priority == .urgent || message.priority == .high
                        }
                        
                        Task { @MainActor in
                            // Remove old messages from this conversation
                            self.allPriorityMessages.removeAll { $0.conversationId == conversationId }
                            
                            // Add new priority messages
                            let priorityMessages = messages.map { message in
                                PriorityMessage(
                                    id: "\(conversationId)_\(message.id)",
                                    message: message,
                                    conversationId: conversationId
                                )
                            }
                            
                            self.allPriorityMessages.append(contentsOf: priorityMessages)
                            
                            // Sort by creation date (newest first)
                            self.allPriorityMessages.sort { $0.message.createdAt > $1.message.createdAt }
                        }
                    }
                    
                    listeners.append(listener)
                }
                
                isLoading = false
                
                print("✅ Listening to priority messages from \(conversationsSnapshot.documents.count) conversations")
                
            } catch {
                print("❌ Failed to load priority messages: \(error.localizedDescription)")
                isLoading = false
            }
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        allPriorityMessages = []
        conversationNames = [:]
    }
    
    deinit {
        listeners.forEach { $0.remove() }
    }
}

