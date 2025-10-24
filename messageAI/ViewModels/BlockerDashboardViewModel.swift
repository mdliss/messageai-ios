//
//  BlockerDashboardViewModel.swift
//  messageAI
//
//  Advanced AI Feature: Proactive Blocker Detection
//  ViewModel managing blocker dashboard and resolution actions
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

/// ViewModel managing blocker dashboard
@MainActor
class BlockerDashboardViewModel: ObservableObject {
    @Published var activeBlockers: [Blocker] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var listenerTasks: [Task<Void, Never>] = []
    
    /// Load active blockers for current user's conversations
    /// - Parameter userId: Current user ID
    func loadActiveBlockers(for userId: String) async {
        print("🔍 loading active blockers for user: \(userId)")
        isLoading = true
        errorMessage = nil
        
        do {
            // Get all conversations user is part of
            let conversationsRef = db.collection("conversations")
                .whereField("participantIds", arrayContains: userId)
            
            let conversationsSnapshot = try await conversationsRef.getDocuments()
            
            print("📁 found \(conversationsSnapshot.documents.count) conversations")
            
            // Fetch active blockers from each conversation
            var allBlockers: [Blocker] = []
            
            for convoDoc in conversationsSnapshot.documents {
                let conversationId = convoDoc.documentID
                
                // Query active blockers
                let blockersRef = db.collection("conversations")
                    .document(conversationId)
                    .collection("blockers")
                    .whereField("status", isEqualTo: "active")
                
                let blockersSnapshot = try await blockersRef.getDocuments()
                
                print("📊 found \(blockersSnapshot.documents.count) active blockers in conversation \(conversationId)")
                
                // Parse blockers
                for blockerDoc in blockersSnapshot.documents {
                    if let blocker = Blocker(from: blockerDoc.data()) {
                        allBlockers.append(blocker)
                    }
                }
            }
            
            // Sort by severity (critical first) then time (oldest first)
            self.activeBlockers = allBlockers.sorted { b1, b2 in
                if b1.severity != b2.severity {
                    return b1.severity < b2.severity
                }
                return b1.detectedAt < b2.detectedAt
            }
            
            print("✅ loaded \(self.activeBlockers.count) total active blockers")
            
            isLoading = false
            
        } catch {
            print("❌ failed to load blockers: \(error.localizedDescription)")
            errorMessage = "couldn't load blockers"
            isLoading = false
        }
    }
    
    /// Mark blocker as resolved
    /// - Parameters:
    ///   - blocker: Blocker to resolve
    ///   - notes: Optional resolution notes
    ///   - currentUserId: Manager user ID
    func markResolved(_ blocker: Blocker, notes: String?, currentUserId: String) async {
        print("✅ marking blocker as resolved: \(blocker.id)")
        
        let blockerRef = db.collection("conversations")
            .document(blocker.conversationId)
            .collection("blockers")
            .document(blocker.id)
        
        do {
            var updateData: [String: Any] = [
                "status": "resolved",
                "resolvedAt": Date(),
                "resolvedBy": currentUserId
            ]
            
            if let notes = notes, !notes.isEmpty {
                updateData["resolutionNotes"] = notes
            }
            
            try await blockerRef.updateData(updateData)
            
            // Remove from active list
            activeBlockers.removeAll { $0.id == blocker.id }
            
            print("✅ blocker marked as resolved")
            
        } catch {
            print("❌ failed to mark blocker as resolved: \(error.localizedDescription)")
        }
    }
    
    /// Snooze blocker for specified duration
    /// - Parameters:
    ///   - blocker: Blocker to snooze
    ///   - duration: Snooze duration in seconds
    func snooze(_ blocker: Blocker, duration: TimeInterval) async {
        print("⏰ snoozing blocker for \(duration / 3600) hours: \(blocker.id)")
        
        let blockerRef = db.collection("conversations")
            .document(blocker.conversationId)
            .collection("blockers")
            .document(blocker.id)
        
        let snoozedUntil = Date().addingTimeInterval(duration)
        
        do {
            try await blockerRef.updateData([
                "status": "snoozed",
                "snoozedUntil": snoozedUntil
            ])
            
            // Remove from active list
            activeBlockers.removeAll { $0.id == blocker.id }
            
            print("✅ blocker snoozed until \(snoozedUntil)")
            
        } catch {
            print("❌ failed to snooze blocker: \(error.localizedDescription)")
        }
    }
    
    /// Mark blocker as false positive
    /// - Parameter blocker: Blocker to mark as false positive
    func markFalsePositive(_ blocker: Blocker) async {
        print("❌ marking blocker as false positive: \(blocker.id)")
        
        let blockerRef = db.collection("conversations")
            .document(blocker.conversationId)
            .collection("blockers")
            .document(blocker.id)
        
        do {
            try await blockerRef.updateData([
                "status": "false_positive",
                "managerMarkedFalsePositive": true
            ])
            
            // Remove from active list
            activeBlockers.removeAll { $0.id == blocker.id }
            
            print("✅ blocker marked as false positive")
            
        } catch {
            print("❌ failed to mark as false positive: \(error.localizedDescription)")
        }
    }
}

