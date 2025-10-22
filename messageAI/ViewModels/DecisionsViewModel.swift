//
//  DecisionsViewModel.swift
//  messageAI
//
//  Created by MessageAI Team
//  ViewModel for tracking team decisions
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

/// ViewModel managing decision tracking
@MainActor
class DecisionsViewModel: ObservableObject {
    @Published var decisions: [AIInsight] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = FirebaseConfig.shared.db
    private var decisionsTask: Task<Void, Never>?
    private var listeners: [ListenerRegistration] = []
    
    // MARK: - Load Decisions
    
    /// Load all decisions across conversations (polls and team decisions)
    /// - Parameter userId: Current user ID
    func loadDecisions(userId: String) {
        isLoading = true
        
        decisionsTask = Task {
            // Get all conversations for user
            let conversationsRef = db.collection("conversations")
                .whereField("participantIds", arrayContains: userId)
            
            do {
                let conversationsSnapshot = try await conversationsRef.getDocuments()
                var allDecisions: [AIInsight] = []
                
                // Set up real-time listeners for each conversation's insights
                for conversationDoc in conversationsSnapshot.documents {
                    let conversationData = conversationDoc.data()
                    let conversationType = conversationData["type"] as? String ?? "direct"
                    let participantCount = (conversationData["participantIds"] as? [String])?.count ?? 0
                    
                    let insightsRef = conversationDoc.reference
                        .collection("insights")
                        .whereField("type", isEqualTo: "decision")
                        .whereField("dismissed", isEqualTo: false)
                    
                    // Use real-time listener for live vote updates
                    let listener = insightsRef.addSnapshotListener { [weak self] snapshot, error in
                        guard let self = self else { return }
                        
                        if let error = error {
                            print("❌ Error listening to insights: \(error.localizedDescription)")
                            return
                        }
                        
                        guard let documents = snapshot?.documents else { return }
                        
                        let insights = documents.compactMap { doc -> AIInsight? in
                            try? doc.data(as: AIInsight.self)
                        }.filter { insight in
                            // Show polls for all conversations with 2+ people
                            // Show regular decisions only for group chats (3+ people)
                            let isPoll = insight.metadata?.isPoll == true
                            
                            if isPoll {
                                // Polls visible for any conversation with 2+ participants
                                return participantCount >= 2
                            } else {
                                // Regular decisions only for group chats (3+ participants)
                                return conversationType == "group" || participantCount >= 3
                            }
                        }
                        
                        Task { @MainActor in
                            // Remove old insights from this conversation
                            let conversationId = conversationDoc.documentID
                            self.decisions.removeAll { $0.conversationId == conversationId }
                            
                            // Add new insights
                            self.decisions.append(contentsOf: insights)
                            
                            // Sort by creation date (newest first)
                            self.decisions.sort { $0.createdAt > $1.createdAt }
                        }
                    }
                    
                    self.listeners.append(listener)
                }
                
                self.isLoading = false
                
                print("✅ Listening to decisions from \(conversationsSnapshot.documents.count) conversations")
                
            } catch {
                self.errorMessage = "Failed to load decisions: \(error.localizedDescription)"
                self.isLoading = false
                print("❌ Failed to load decisions: \(error.localizedDescription)")
            }
        }
    }
    
    /// Search decisions
    /// - Parameter query: Search query
    /// - Returns: Filtered decisions
    func searchDecisions(query: String) -> [AIInsight] {
        guard !query.isEmpty else {
            return decisions
        }
        
        return decisions.filter { decision in
            decision.content.localizedCaseInsensitiveContains(query)
        }
    }
    
    /// Group decisions by date
    /// - Returns: Dictionary of decisions grouped by date string
    func groupedByDate() -> [(key: String, value: [AIInsight])] {
        let grouped = Dictionary(grouping: decisions) { decision -> String in
            let calendar = Calendar.current
            if calendar.isDateInToday(decision.createdAt) {
                return "today"
            } else if calendar.isDateInYesterday(decision.createdAt) {
                return "yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return formatter.string(from: decision.createdAt)
            }
        }
        
        return grouped.sorted { $0.value.first?.createdAt ?? Date() > $1.value.first?.createdAt ?? Date() }
    }
    
    // MARK: - Voting
    
    /// Cast vote on a meeting poll
    /// - Parameters:
    ///   - decision: The poll decision
    ///   - userId: User ID voting
    ///   - optionIndex: Selected option index (0, 1, or 2)
    func voteOnPoll(decision: AIInsight, userId: String, optionIndex: Int) async {
        do {
            let insightRef = db.collection("conversations")
                .document(decision.conversationId)
                .collection("insights")
                .document(decision.id)
            
            try await insightRef.updateData([
                "metadata.votes.\(userId)": "option_\(optionIndex + 1)"
            ])
            
            print("✅ Vote cast: option \(optionIndex + 1)")
            
        } catch {
            errorMessage = "Failed to vote: \(error.localizedDescription)"
            print("❌ Failed to vote: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        decisionsTask?.cancel()
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    deinit {
        decisionsTask?.cancel()
        listeners.forEach { $0.remove() }
    }
}

