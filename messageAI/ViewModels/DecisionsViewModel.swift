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
        print("🔄 loadDecisions called for user: \(userId)")
        print("📊 Current listeners count: \(listeners.count)")
        print("📊 Current decisions count: \(decisions.count)")
        
        // CRITICAL FIX: Clean up existing listeners before creating new ones
        // This prevents duplicate listeners when navigating back to Decisions tab
        cleanup()
        
        isLoading = true
        
        decisionsTask = Task {
            // Get all conversations for user
            let conversationsRef = db.collection("conversations")
                .whereField("participantIds", arrayContains: userId)
            
            do {
                let conversationsSnapshot = try await conversationsRef.getDocuments()
                
                print("✅ Found \(conversationsSnapshot.documents.count) conversations for user")
                
                // Set up real-time listeners for each conversation's insights
                for conversationDoc in conversationsSnapshot.documents {
                    let conversationData = conversationDoc.data()
                    let conversationType = conversationData["type"] as? String ?? "direct"
                    let participantCount = (conversationData["participantIds"] as? [String])?.count ?? 0
                    
                    print("📝 Setting up listener for conversation: \(conversationDoc.documentID)")
                    print("   Conversation type: \(conversationType), participants: \(participantCount)")
                    
                    // CRITICAL FIX: Do NOT filter by dismissed status in Decisions tab
                    // Decisions tab is a permanent historical record - should show all confirmed decisions
                    // regardless of whether notification was dismissed in chat
                    // Only filter by type="decision" to get all decision-related insights
                    let insightsRef = conversationDoc.reference
                        .collection("insights")
                        .whereField("type", isEqualTo: "decision")
                    
                    print("   Query: conversations/\(conversationDoc.documentID)/insights where type='decision' (NO dismissed filter)")
                    
                    // Use real-time listener for live vote updates
                    let listener = insightsRef.addSnapshotListener { [weak self] snapshot, error in
                        guard let self = self else { return }
                        
                        if let error = error {
                            print("❌ Error listening to insights: \(error.localizedDescription)")
                            return
                        }
                        
                        guard let documents = snapshot?.documents else {
                            print("⚠️ No documents in snapshot for conversation \(conversationDoc.documentID)")
                            return
                        }
                        
                        print("📥 Received \(documents.count) documents from Firestore for conversation \(conversationDoc.documentID)")
                        
                        let insights = documents.compactMap { doc -> AIInsight? in
                            let insight = try? doc.data(as: AIInsight.self)
                            if let insight = insight {
                                let isPoll = insight.metadata?.isPoll == true
                                let pollId = insight.metadata?.pollId
                                let pollStatus = insight.metadata?.pollStatus ?? "unknown"
                                print("   📄 Document \(doc.documentID): isPoll=\(isPoll), pollId=\(pollId ?? "nil"), pollStatus=\(pollStatus)")
                            }
                            return insight
                        }.filter { insight in
                            // Show different decision types based on context
                            let isPoll = insight.metadata?.isPoll == true
                            let isConsenusDecision = insight.metadata?.pollId != nil
                            let pollStatus = insight.metadata?.pollStatus ?? "active"
                            
                            print("   🔍 Filtering \(insight.id): isPoll=\(isPoll), isConsensus=\(isConsenusDecision), pollStatus=\(pollStatus)")
                            
                            if isPoll {
                                // CRITICAL: Show ALL polls (active and confirmed) for historical record
                                // Previously only showed active polls, causing confirmed polls to disappear
                                let shouldShow = participantCount >= 2
                                print("      → Poll: showing=\(shouldShow) (participants: \(participantCount))")
                                return shouldShow
                            } else if isConsenusDecision {
                                // CRITICAL FIX: Always show consensus decisions regardless of participant count
                                // These are important final decisions that reached agreement
                                print("      → Consensus decision: showing=true (always show)")
                                return true
                            } else {
                                // Regular decisions only for group chats (3+ participants)
                                let shouldShow = conversationType == "group" || participantCount >= 3
                                print("      → Regular decision: showing=\(shouldShow) (type: \(conversationType))")
                                return shouldShow
                            }
                        }
                        
                        print("✅ After filtering: \(insights.count) insights to display")
                        
                        Task { @MainActor in
                            // Remove old insights from this conversation
                            let conversationId = conversationDoc.documentID
                            let oldCount = self.decisions.filter { $0.conversationId == conversationId }.count
                            self.decisions.removeAll { $0.conversationId == conversationId }
                            print("🔄 Removed \(oldCount) old insights, adding \(insights.count) new insights")
                            
                            // Add new insights
                            self.decisions.append(contentsOf: insights)
                            
                            // Sort by creation date (newest first)
                            self.decisions.sort { $0.createdAt > $1.createdAt }
                            
                            print("📊 Total decisions now: \(self.decisions.count)")
                        }
                    }
                    
                    self.listeners.append(listener)
                    print("✅ Listener attached for conversation \(conversationDoc.documentID)")
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
            print("📝 Poll document path: conversations/\(decision.conversationId)/insights/\(decision.id)")
            
            // create decision entry
            let decisionRef = db.collection("conversations")
                .document(decision.conversationId)
                .collection("insights")
                .document()
            
            let totalVotes = votes.count
            let consensusReached = voteCounts.count == 1 && voteCount == totalVotes
            
            print("📊 Creating decision document:")
            print("   Decision ID: \(decisionRef.documentID)")
            print("   Path: conversations/\(decision.conversationId)/insights/\(decisionRef.documentID)")
            print("   Type: decision")
            print("   Poll ID: \(decision.id)")
            print("   Winning option: \(winningOption)")
            print("   Vote count: \(voteCount) of \(totalVotes)")
            print("   Consensus: \(consensusReached)")
            
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
            
            print("📤 Writing decision document to Firestore...")
            try await decisionRef.setData(decisionData)
            
            print("✅ Decision entry created successfully!")
            print("   Document ID: \(decisionRef.documentID)")
            print("   This decision should now appear in Decisions tab for all participants")
            print("   Real-time listener will pick it up automatically")
            
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

    /// Delete poll or decision permanently
    /// - Parameters:
    ///   - decision: The decision/poll to delete
    ///   - userId: Current user ID
    func deleteDecision(decision: AIInsight, userId: String) async {
        do {
            print("🗑️ deleting decision \(decision.id) for user \(userId)")

            let insightRef = db.collection("conversations")
                .document(decision.conversationId)
                .collection("insights")
                .document(decision.id)

            // Delete the document
            try await insightRef.delete()

            print("✅ decision deleted successfully")

            // Remove from local array immediately (optimistic UI)
            decisions.removeAll { $0.id == decision.id }

            // If this was a poll that created a consensus decision, also delete that
            if let metadata = decision.metadata, metadata.isPoll == true {
                // Find and delete any consensus decisions created from this poll
                let consensusDecisions = decisions.filter { $0.metadata?.pollId == decision.id }
                for consensusDecision in consensusDecisions {
                    let consensusRef = db.collection("conversations")
                        .document(consensusDecision.conversationId)
                        .collection("insights")
                        .document(consensusDecision.id)

                    try await consensusRef.delete()
                    decisions.removeAll { $0.id == consensusDecision.id }
                    print("✅ deleted related consensus decision \(consensusDecision.id)")
                }
            }

        } catch {
            errorMessage = "failed to delete: \(error.localizedDescription)"
            print("❌ failed to delete decision: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        print("🧹 Cleanup called - removing \(listeners.count) listeners")
        decisionsTask?.cancel()
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        print("✅ Cleanup complete - all listeners removed")
    }
    
    deinit {
        print("💀 DecisionsViewModel deinit - cleaning up \(listeners.count) listeners")
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

