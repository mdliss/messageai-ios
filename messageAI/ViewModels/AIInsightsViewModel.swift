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

