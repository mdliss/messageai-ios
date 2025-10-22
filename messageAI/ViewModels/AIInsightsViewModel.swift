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
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let functions = Functions.functions()
    private let db = FirebaseConfig.shared.db
    
    private var insightsTask: Task<Void, Never>?
    
    // MARK: - Subscribe to Insights
    
    /// Subscribe to insights for a conversation
    /// - Parameter conversationId: Conversation ID
    func subscribeToInsights(conversationId: String) {
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
                }
                
                Task { @MainActor in
                    self.insights = fetchedInsights
                    print("✅ Fetched \(fetchedInsights.count) insights")
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
    
    /// Summarize conversation
    /// - Parameter conversationId: Conversation ID
    /// - Returns: AI insight with summary
    func summarize(conversationId: String) async throws -> AIInsight {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await functions.httpsCallable("summarizeConversation").call([
                "conversationId": conversationId
            ])
            
            guard let data = result.data as? [String: Any],
                  let insightData = data["insight"] as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: insightData),
                  let insight = try? JSONDecoder().decode(AIInsight.self, from: jsonData) else {
                throw AIError.invalidResponse
            }
            
            isLoading = false
            print("✅ Summary generated")
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
    
    /// Accept scheduling suggestion and post suggested times as AI assistant message
    /// - Parameters:
    ///   - insight: The scheduling suggestion insight
    ///   - conversationId: Conversation ID
    ///   - currentUserId: Current user ID
    ///   - currentUserName: Current user display name
    func acceptSuggestion(insight: AIInsight, conversationId: String, currentUserId: String, currentUserName: String) async {
        do {
            // Extract suggested times from insight metadata or content
            let suggestedTimes = insight.metadata?.suggestedTimes ?? extractTimesFromContent(insight.content)
            
            // Create AI assistant message with suggested times
            let assistantMessage = """
            🤖 scheduling assistant
            
            based on the conversation, here are some suggested meeting times:
            
            \(suggestedTimes)
            
            please let me know which time works best for everyone, or if you need different options.
            """
            
            // Post as a system message (AI assistant)
            let messageRef = db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .document()
            
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
            
            print("✅ Scheduling suggestion accepted and posted as AI assistant message")
            
        } catch {
            errorMessage = "Failed to accept suggestion: \(error.localizedDescription)"
            print("❌ Failed to accept suggestion: \(error.localizedDescription)")
        }
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
    
    // MARK: - Dismiss Insight
    
    /// Dismiss an insight
    /// - Parameters:
    ///   - insightId: Insight ID
    ///   - conversationId: Conversation ID
    func dismissInsight(insightId: String, conversationId: String) async {
        do {
            let insightRef = db.collection("conversations")
                .document(conversationId)
                .collection("insights")
                .document(insightId)
            
            try await insightRef.updateData([
                "dismissed": true
            ])
            
            // Remove from local array
            insights.removeAll { $0.id == insightId }
            
            print("✅ Insight dismissed: \(insightId)")
        } catch {
            errorMessage = "Failed to dismiss insight: \(error.localizedDescription)"
            print("❌ Failed to dismiss insight: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        insightsTask?.cancel()
        insights = []
    }
    
    deinit {
        insightsTask?.cancel()
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

