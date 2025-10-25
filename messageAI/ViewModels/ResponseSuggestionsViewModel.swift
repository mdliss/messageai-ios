//
//  ResponseSuggestionsViewModel.swift
//  messageAI
//
//  Advanced AI Feature: Smart Response Suggestions
//  ViewModel managing response suggestion generation and selection
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseFunctions

/// ViewModel managing response suggestions
@MainActor
class ResponseSuggestionsViewModel: ObservableObject {
    @Published var suggestions: [ResponseSuggestion] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let functions = FirebaseConfig.shared.functions
    private let db = FirebaseConfig.shared.db
    
    /// Generate response suggestions for a message
    /// - Parameters:
    ///   - message: Message requiring response
    ///   - conversationId: Conversation ID
    ///   - currentUserId: Current user ID (manager)
    func generateSuggestions(for message: Message, in conversationId: String, currentUserId: String) async {
        print("🎯 generating response suggestions for message: \(message.id)")
        
        isLoading = true
        errorMessage = nil
        suggestions = []
        
        let startTime = Date()
        
        do {
            // Call cloud function
            print("📡 calling generateResponseSuggestions cloud function...")
            
            let result = try await functions.httpsCallable("generateResponseSuggestions").call([
                "conversationId": conversationId,
                "messageId": message.id,
                "currentUserId": currentUserId
            ])
            
            guard let data = result.data as? [String: Any] else {
                throw NSError(domain: "ResponseSuggestions", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "invalid response format"
                ])
            }
            
            print("📊 cloud function response: \(data)")
            
            // Check if this was a cached result
            let wasCached = data["cached"] as? Bool ?? false
            if wasCached {
                print("✅ using cached suggestions")
            }
            
            // Parse suggestions
            guard let optionsData = data["options"] as? [[String: Any]] else {
                throw NSError(domain: "ResponseSuggestions", code: -2, userInfo: [
                    NSLocalizedDescriptionKey: "options not found in response"
                ])
            }
            
            // Decode each suggestion
            var parsedSuggestions: [ResponseSuggestion] = []
            
            for (index, optionDict) in optionsData.enumerated() {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: optionDict)
                    let suggestion = try JSONDecoder().decode(ResponseSuggestion.self, from: jsonData)
                    parsedSuggestions.append(suggestion)
                    print("✅ parsed suggestion \(index + 1): \(suggestion.type.rawValue)")
                } catch {
                    print("⚠️ failed to parse suggestion \(index + 1): \(error.localizedDescription)")
                }
            }
            
            self.suggestions = parsedSuggestions
            
            let elapsed = Date().timeIntervalSince(startTime)
            print("✅ loaded \(parsedSuggestions.count) suggestions in \(String(format: "%.2f", elapsed))s")
            
            self.isLoading = false
            
        } catch {
            print("❌ failed to generate suggestions: \(error.localizedDescription)")
            self.errorMessage = "couldn't generate suggestions. please try again."
            self.isLoading = false
        }
    }
    
    /// Select a suggestion (tracks usage for learning)
    /// - Parameters:
    ///   - suggestion: Selected suggestion
    ///   - messageId: Message ID
    ///   - conversationId: Conversation ID
    func selectSuggestion(_ suggestion: ResponseSuggestion, messageId: String, conversationId: String) {
        print("📝 tracking suggestion selection: \(suggestion.id)")
        
        // Track selection in Firestore for learning
        Task {
            await recordSuggestionUsage(
                messageId: messageId,
                conversationId: conversationId,
                suggestionId: suggestion.id,
                wasEdited: false  // Will be updated if user edits before sending
            )
        }
    }
    
    /// Provide feedback on suggestion quality
    /// - Parameters:
    ///   - messageId: Message ID
    ///   - conversationId: Conversation ID
    ///   - helpful: Whether suggestions were helpful
    func provideFeedback(messageId: String, conversationId: String, helpful: Bool) {
        print("👍 recording suggestion feedback: \(helpful ? "helpful" : "not helpful")")
        
        Task {
            await recordFeedback(
                messageId: messageId,
                conversationId: conversationId,
                rating: helpful ? "helpful" : "not_helpful"
            )
        }
    }
    
    /// Dismiss all suggestions
    func dismissSuggestions() {
        print("❌ dismissing suggestions")
        suggestions = []
        errorMessage = nil
    }
    
    /// Clear loading and error states
    func reset() {
        suggestions = []
        isLoading = false
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    /// Record suggestion usage in Firestore
    private func recordSuggestionUsage(messageId: String, conversationId: String, suggestionId: String, wasEdited: Bool) async {
        do {
            let messageRef = db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .document(messageId)
            
            try await messageRef.updateData([
                "suggestionFeedback.wasUsed": true,
                "suggestionFeedback.selectedOptionId": suggestionId,
                "suggestionFeedback.wasEdited": wasEdited
            ])
            
            print("✅ suggestion usage recorded")
        } catch {
            print("⚠️ failed to record suggestion usage: \(error.localizedDescription)")
        }
    }
    
    /// Record feedback rating in Firestore
    private func recordFeedback(messageId: String, conversationId: String, rating: String) async {
        do {
            let messageRef = db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .document(messageId)
            
            try await messageRef.updateData([
                "suggestionFeedback.userRating": rating
            ])
            
            print("✅ feedback recorded")
        } catch {
            print("⚠️ failed to record feedback: \(error.localizedDescription)")
        }
    }
}

