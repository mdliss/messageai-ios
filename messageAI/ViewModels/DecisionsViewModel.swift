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
    
    // MARK: - Load Decisions
    
    /// Load all decisions across conversations
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
                
                // Fetch decisions from each conversation
                for conversationDoc in conversationsSnapshot.documents {
                    let insightsRef = conversationDoc.reference
                        .collection("insights")
                        .whereField("type", isEqualTo: "decision")
                        .whereField("dismissed", isEqualTo: false)
                    
                    let insightsSnapshot = try await insightsRef.getDocuments()
                    
                    let insights = insightsSnapshot.documents.compactMap { doc -> AIInsight? in
                        try? doc.data(as: AIInsight.self)
                    }
                    
                    allDecisions.append(contentsOf: insights)
                }
                
                // Sort by creation date (newest first)
                self.decisions = allDecisions.sorted { $0.createdAt > $1.createdAt }
                self.isLoading = false
                
                print("✅ Loaded \(allDecisions.count) decisions")
                
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
    
    // MARK: - Cleanup
    
    func cleanup() {
        decisionsTask?.cancel()
    }
    
    deinit {
        decisionsTask?.cancel()
    }
}

