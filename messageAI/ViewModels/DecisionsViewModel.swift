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
                            // Show different decision types based on context
                            let isPoll = insight.metadata?.isPoll == true
                            let isConsenusDecision = insight.metadata?.pollId != nil
                            
                            if isPoll {
                                // Polls visible for any conversation with 2+ participants
                                return participantCount >= 2
                            } else if isConsenusDecision {
                                // CRITICAL FIX: Always show consensus decisions regardless of participant count
                                // These are important final decisions that reached agreement
                                return true
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
    
    // MARK: - Poll Confirmation
    
    /// Confirm poll and create decision
    /// - Parameters:
    ///   - decision: The poll to confirm
    ///   - userId: Current user ID
    func confirmPoll(decision: AIInsight, userId: String) async {
        do {
            print("🎯 confirming poll \(decision.id) for user \(userId)")
            
            let insightRef = db.collection("conversations")
                .document(decision.conversationId)
                .collection("insights")
                .document(decision.id)
            
            // calculate winning option
            let votes = decision.metadata?.votes ?? [:]
            var voteCounts: [String: Int] = [:]
            
            for (_, option) in votes {
                voteCounts[option, default: 0] += 1
            }
            
            let winningOption = voteCounts.max(by: { $0.value < $1.value })?.key ?? "option_1"
            let voteCount = voteCounts[winningOption] ?? 0
            
            print("📊 winning option: \(winningOption) with \(voteCount) votes")
            
            // get time options
            let timeOptions = decision.metadata?.timeOptions ?? []
            let winningIndex = Int(winningOption.split(separator: "_")[1])! - 1
            let winningTime = timeOptions[safe: winningIndex] ?? "selected time"
            
            print("⏰ winning time: \(winningTime)")
            
            // update poll to confirmed
            try await insightRef.updateData([
                "metadata.pollStatus": "confirmed",
                "metadata.winningOption": winningOption,
                "metadata.winningTime": winningTime,
                "metadata.confirmedBy": userId,
                "metadata.confirmedAt": Timestamp(date: Date()),
                "metadata.finalized": true
            ])
            
            print("✅ poll confirmed successfully")
            
            // create decision entry
            let decisionRef = db.collection("conversations")
                .document(decision.conversationId)
                .collection("insights")
                .document()
            
            let totalVotes = votes.count
            let consensusReached = voteCounts.count == 1 && voteCount == totalVotes
            
            let decisionData: [String: Any] = [
                "id": decisionRef.documentID,
                "conversationId": decision.conversationId,
                "type": "decision",
                "content": "meeting scheduled: \(winningTime)",
                "metadata": [
                    "pollId": decision.id,
                    "winningOption": winningOption,
                    "winningTime": winningTime,
                    "voteCount": voteCount,
                    "totalVotes": totalVotes,
                    "consensusReached": consensusReached
                ],
                "messageIds": decision.messageIds,
                "triggeredBy": userId,
                "createdAt": Timestamp(date: Date()),
                "dismissed": false
            ]
            
            try await decisionRef.setData(decisionData)
            
            print("✅ decision entry created: \(decisionRef.documentID)")
            
            // post system message
            let messageRef = db.collection("conversations")
                .document(decision.conversationId)
                .collection("messages")
                .document()
            
            let messageData: [String: Any] = [
                "id": messageRef.documentID,
                "conversationId": decision.conversationId,
                "senderId": "ai_assistant",
                "senderName": "ai assistant",
                "senderPhotoURL": NSNull(),
                "type": "text",
                "text": "✅ poll confirmed! meeting scheduled for:\n\n\(winningTime)\n\n(\(voteCount) of \(totalVotes) votes)",
                "imageURL": NSNull(),
                "createdAt": Timestamp(date: Date()),
                "status": "sent",
                "deliveredTo": [],
                "readBy": [],
                "localId": NSNull(),
                "isSynced": true,
                "priority": false
            ]
            
            try await messageRef.setData(messageData)
            
            print("✅ system message posted")
            
        } catch {
            errorMessage = "failed to confirm poll: \(error.localizedDescription)"
            print("❌ failed to confirm poll: \(error.localizedDescription)")
        }
    }
    
    /// Cancel poll
    /// - Parameters:
    ///   - decision: The poll to cancel
    ///   - userId: Current user ID
    func cancelPoll(decision: AIInsight, userId: String) async {
        do {
            print("🚫 cancelling poll \(decision.id) for user \(userId)")
            
            let insightRef = db.collection("conversations")
                .document(decision.conversationId)
                .collection("insights")
                .document(decision.id)
            
            // update poll to cancelled
            try await insightRef.updateData([
                "metadata.pollStatus": "cancelled",
                "dismissed": true
            ])
            
            print("✅ poll cancelled successfully")
            
            // post system message
            let messageRef = db.collection("conversations")
                .document(decision.conversationId)
                .collection("messages")
                .document()
            
            let messageData: [String: Any] = [
                "id": messageRef.documentID,
                "conversationId": decision.conversationId,
                "senderId": "ai_assistant",
                "senderName": "ai assistant",
                "senderPhotoURL": NSNull(),
                "type": "text",
                "text": "🚫 poll cancelled by creator",
                "imageURL": NSNull(),
                "createdAt": Timestamp(date: Date()),
                "status": "sent",
                "deliveredTo": [],
                "readBy": [],
                "localId": NSNull(),
                "isSynced": true,
                "priority": false
            ]
            
            try await messageRef.setData(messageData)
            
            print("✅ cancellation message posted")
            
        } catch {
            errorMessage = "failed to cancel poll: \(error.localizedDescription)"
            print("❌ failed to cancel poll: \(error.localizedDescription)")
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

// MARK: - Array Safe Subscript Extension

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

