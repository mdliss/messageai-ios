//
//  AIInsightsViewModel.swift
//  messageAI
//
//  Created by MessageAI Team
//  ViewModel for AI insights and features
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseFunctions

/// ViewModel managing AI insights
@MainActor
class AIInsightsViewModel: ObservableObject {
    @Published var insights: [AIInsight] = []
    @Published var currentUserSummary: AIInsight? = nil  // Per-user summary (not shared)
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let functions = Functions.functions()
    private let db = FirebaseConfig.shared.db
    
    private var insightsTask: Task<Void, Never>?
    private var summaryTask: Task<Void, Never>?
    
    // MARK: - Subscribe to Insights
    
    /// Subscribe to insights for a conversation
    /// - Parameters:
    ///   - conversationId: Conversation ID
    ///   - currentUserId: Current user ID to filter targeted suggestions
    func subscribeToInsights(conversationId: String, currentUserId: String) {
        // Subscribe to SHARED insights (excludes summaries which are now per-user)
        let insightsRef = db.collection("conversations")
            .document(conversationId)
            .collection("insights")
            .whereField("dismissed", isEqualTo: false)
            .order(by: "createdAt")
        
        insightsTask = Task {
            let listener = insightsRef.addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error fetching insights: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    Task { @MainActor in
                        self.insights = []
                    }
                    return
                }
                
                let fetchedInsights = documents.compactMap { document -> AIInsight? in
                    try? document.data(as: AIInsight.self)
                }.filter { insight in
                    // CRITICAL FIX: Exclude summaries (they're now per-user)
                    if insight.type == .summary {
                        return false
                    }
                    
                    // Show all insights except suggestions targeted at other users
                    if insight.type == .suggestion,
                       let targetUserId = insight.metadata?.targetUserId,
                       targetUserId != currentUserId {
                        return false
                    }
                    return true
                }
                
                Task { @MainActor in
                    self.insights = fetchedInsights
                    print("✅ Fetched \(fetchedInsights.count) shared insights (no summaries, filtered for user \(currentUserId))")
                }
            }
            
            // Keep listener alive
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            
            listener.remove()
        }
        
        // Subscribe to PER-USER summaries (ephemeral, not shared)
        subscribeToUserSummaries(conversationId: conversationId, currentUserId: currentUserId)
    }
    
    /// Subscribe to current user's ephemeral summaries
    /// - Parameters:
    ///   - conversationId: Conversation ID
    ///   - currentUserId: Current user ID
    private func subscribeToUserSummaries(conversationId: String, currentUserId: String) {
        let summaryRef = db.collection("users")
            .document(currentUserId)
            .collection("ephemeral")
            .document("summaries")
            .collection(conversationId)
            .order(by: "createdAt", descending: true)
            .limit(to: 1)  // Only need the latest summary
        
        summaryTask = Task {
            let listener = summaryRef.addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error fetching user summary: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents,
                      let latestDoc = documents.first else {
                    Task { @MainActor in
                        self.currentUserSummary = nil
                    }
                    return
                }
                
                if let summary = try? latestDoc.data(as: AIInsight.self),
                   !summary.dismissed {
                    Task { @MainActor in
                        self.currentUserSummary = summary
                        print("✅ Fetched per-user summary (only visible to \(currentUserId))")
                    }
                } else {
                    Task { @MainActor in
                        self.currentUserSummary = nil
                    }
                }
            }
            
            // Keep listener alive
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            
            listener.remove()
        }
    }
    
    // MARK: - Summarize
    
    /// Summarize conversation (per-user, not shared)
    /// - Parameters:
    ///   - conversationId: Conversation ID
    ///   - currentUserId: Current user ID
    /// - Returns: AI insight with summary
    func summarize(conversationId: String, currentUserId: String) async throws -> AIInsight {
        isLoading = true
        errorMessage = nil
        
        do {
            // Call Cloud Function to generate summary
            let result = try await functions.httpsCallable("summarizeConversation").call([
                "conversationId": conversationId,
                "userId": currentUserId  // Pass user ID for per-user storage
            ])
            
            guard let data = result.data as? [String: Any],
                  let insightData = data["insight"] as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: insightData),
                  var insight = try? JSONDecoder().decode(AIInsight.self, from: jsonData) else {
                throw AIError.invalidResponse
            }
            
            // CRITICAL FIX: Store summary in per-user ephemeral collection
            // Path: users/{userId}/ephemeral/summaries/{conversationId}/{summaryId}
            let summaryRef = db.collection("users")
                .document(currentUserId)
                .collection("ephemeral")
                .document("summaries")
                .collection(conversationId)
                .document()
            
            // Update insight ID to match the Firestore document
            insight = AIInsight(
                id: summaryRef.documentID,
                conversationId: insight.conversationId,
                type: insight.type,
                content: insight.content,
                metadata: insight.metadata,
                messageIds: insight.messageIds,
                triggeredBy: currentUserId,
                createdAt: insight.createdAt,
                expiresAt: insight.expiresAt,
                userFeedback: insight.userFeedback,
                dismissed: insight.dismissed
            )
            
            // Save to per-user location
            try await summaryRef.setData(insight.toDictionary())
            
            isLoading = false
            print("✅ Summary generated and stored per-user for \(currentUserId)")
            print("   Path: users/\(currentUserId)/ephemeral/summaries/\(conversationId)/\(summaryRef.documentID)")
            return insight
            
        } catch {
            isLoading = false
            errorMessage = "Failed to summarize: \(error.localizedDescription)"
            print("❌ Summarization failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Extract Action Items
    
    /// Extract action items from conversation
    /// - Parameter conversationId: Conversation ID
    /// - Returns: AI insight with action items
    func extractActionItems(conversationId: String) async throws -> AIInsight {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await functions.httpsCallable("extractActionItems").call([
                "conversationId": conversationId
            ])
            
            guard let data = result.data as? [String: Any],
                  let insightData = data["insight"] as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: insightData),
                  let insight = try? JSONDecoder().decode(AIInsight.self, from: jsonData) else {
                throw AIError.invalidResponse
            }
            
            isLoading = false
            print("✅ Action items extracted")
            return insight
            
        } catch {
            isLoading = false
            errorMessage = "Failed to extract action items: \(error.localizedDescription)"
            print("❌ Action item extraction failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Accept Scheduling Suggestion
    
    /// Accept scheduling suggestion and create voting poll in decisions
    /// - Parameters:
    ///   - insight: The scheduling suggestion insight
    ///   - conversationId: Conversation ID
    ///   - currentUserId: Current user ID
    ///   - currentUserName: Current user display name
    func acceptSuggestion(insight: AIInsight, conversationId: String, currentUserId: String, currentUserName: String) async {
        do {
            // Extract suggested times from insight metadata or content
            let suggestedTimes = insight.metadata?.suggestedTimes ?? extractTimesFromContent(insight.content)
            
            // Parse individual time options
            let timeOptions = parseTimeOptions(from: suggestedTimes)
            
            // Create voting poll as a decision insight
            let pollRef = db.collection("conversations")
                .document(conversationId)
                .collection("insights")
                .document()
            
            let pollContent = """
            📊 meeting time poll
            
            vote for your preferred time:
            
            \(suggestedTimes)
            """
            
            let pollInsight: [String: Any] = [
                "id": pollRef.documentID,
                "conversationId": conversationId,
                "type": "decision",
                "content": pollContent,
                "metadata": [
                    "action": "meeting_poll",
                    "suggestedTimes": suggestedTimes,
                    "timeOptions": timeOptions,
                    "votes": [:],
                    "createdBy": currentUserId,
                    "isPoll": true
                ],
                "messageIds": insight.messageIds,
                "triggeredBy": currentUserId,
                "createdAt": FieldValue.serverTimestamp(),
                "dismissed": false
            ]
            
            try await pollRef.setData(pollInsight)
            
            // Also post AI assistant message in chat for visibility
            let messageRef = db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .document()
            
            let assistantMessage = """
            🤖 scheduling assistant
            
            i've created a poll in the decisions tab where everyone can vote for their preferred meeting time:
            
            \(suggestedTimes)
            
            check the decisions tab at the bottom to cast your vote!
            """
            
            let message: [String: Any] = [
                "id": messageRef.documentID,
                "conversationId": conversationId,
                "senderId": "ai_assistant",
                "senderName": "ai assistant",
                "senderPhotoURL": NSNull(),
                "type": "text",
                "text": assistantMessage,
                "imageURL": NSNull(),
                "createdAt": FieldValue.serverTimestamp(),
                "status": "sent",
                "deliveredTo": [],
                "readBy": [],
                "localId": NSNull(),
                "isSynced": true,
                "priority": false
            ]
            
            try await messageRef.setData(message)
            
            // Dismiss the suggestion insight
            await dismissInsight(insightId: insight.id, conversationId: conversationId)
            
            print("✅ Meeting poll created in decisions tab")
            
        } catch {
            errorMessage = "Failed to accept suggestion: \(error.localizedDescription)"
            print("❌ Failed to accept suggestion: \(error.localizedDescription)")
        }
    }
    
    /// Parse time options from suggested times text
    private func parseTimeOptions(from timesText: String) -> [String] {
        print("🔍 Parsing time options from text: \(timesText)")
        
        let lines = timesText.split(separator: "\n")
        let options = lines.compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Match lines that start with bullet, dash, or contain "option"
            if trimmed.starts(with: "•") || trimmed.starts(with: "-") || trimmed.lowercased().contains("option") {
                return String(trimmed)
            }
            return nil
        }
        
        print("✅ Parsed \(options.count) time options:")
        options.forEach { print("   - \($0)") }
        
        // If parsing failed, create default options
        if options.isEmpty {
            print("⚠️ No options parsed, using defaults")
            return [
                "• option 1: thursday 12pm EST / 9am PST / 5pm GMT / 10:30pm IST",
                "• option 2: friday 10am EST / 7am PST / 3pm GMT / 8:30pm IST",
                "• option 3: friday 1pm EST / 10am PST / 6pm GMT / 11:30pm IST"
            ]
        }
        
        return options
    }
    
    /// Extract suggested times from content if not in metadata
    private func extractTimesFromContent(_ content: String) -> String {
        // Look for "Times:" section in content
        if let timesRange = content.range(of: "Times:", options: .caseInsensitive) {
            let timesSection = String(content[timesRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // If times are found, return them formatted
            if !timesSection.isEmpty {
                return timesSection
            }
        }
        
        // Fallback: return generic suggestion
        return """
        • tomorrow 2pm EST / 11am PST / 7pm GMT
        • thursday 10am EST / 7am PST / 3pm GMT
        • friday 3pm EST / 12pm PST / 8pm GMT
        """
    }
    
    // MARK: - Vote on Meeting Poll
    
    /// Cast vote on meeting time poll
    /// - Parameters:
    ///   - insightId: Poll insight ID
    ///   - conversationId: Conversation ID
    ///   - userId: User ID voting
    ///   - optionIndex: Index of selected option (0, 1, or 2)
    func voteOnPoll(insightId: String, conversationId: String, userId: String, optionIndex: Int) async {
        do {
            let insightRef = db.collection("conversations")
                .document(conversationId)
                .collection("insights")
                .document(insightId)
            
            // Update votes in metadata
            try await insightRef.updateData([
                "metadata.votes.\(userId)": "option_\(optionIndex + 1)"
            ])
            
            print("✅ Vote recorded: User \(userId) voted for option \(optionIndex + 1)")
            
        } catch {
            errorMessage = "Failed to vote: \(error.localizedDescription)"
            print("❌ Failed to vote: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Dismiss Insight
    
    /// Dismiss an insight
    /// - Parameters:
    ///   - insightId: Insight ID
    ///   - conversationId: Conversation ID
    ///   - currentUserId: Current user ID (needed for per-user summaries)
    func dismissInsight(insightId: String, conversationId: String, currentUserId: String) async {
        do {
            // Check if this is a summary (per-user) or shared insight
            if currentUserSummary?.id == insightId {
                // Dismiss per-user summary
                let summaryRef = db.collection("users")
                    .document(currentUserId)
                    .collection("ephemeral")
                    .document("summaries")
                    .collection(conversationId)
                    .document(insightId)
                
                try await summaryRef.updateData([
                    "dismissed": true
                ])
                
                // Clear from local state
                currentUserSummary = nil
                
                print("✅ Per-user summary dismissed: \(insightId)")
            } else {
                // Dismiss shared insight
                let insightRef = db.collection("conversations")
                    .document(conversationId)
                    .collection("insights")
                    .document(insightId)
                
                try await insightRef.updateData([
                    "dismissed": true
                ])
                
                // Remove from local array
                insights.removeAll { $0.id == insightId }
                
                print("✅ Shared insight dismissed: \(insightId)")
            }
        } catch {
            errorMessage = "Failed to dismiss insight: \(error.localizedDescription)"
            print("❌ Failed to dismiss insight: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        insightsTask?.cancel()
        summaryTask?.cancel()
        insights = []
        currentUserSummary = nil
    }
    
    deinit {
        insightsTask?.cancel()
        summaryTask?.cancel()
    }
}

// MARK: - AI Errors

enum AIError: LocalizedError {
    case invalidResponse
    case apiKeyMissing
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from AI service"
        case .apiKeyMissing:
            return "AI API key not configured"
        }
    }
}

