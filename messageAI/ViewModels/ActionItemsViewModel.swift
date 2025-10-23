//
//  ActionItemsViewModel.swift
//  messageAI
//
//  Created by MessageAI Team
//  ViewModel for action items management
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseFunctions

@MainActor
class ActionItemsViewModel: ObservableObject {
    @Published var actionItems: [ActionItem] = []
    @Published var isLoading = false
    @Published var isExtracting = false
    @Published var errorMessage: String?
    
    private let db = FirebaseConfig.shared.db
    private let functions = Functions.functions()
    private var listener: ListenerRegistration?
    
    // MARK: - Load Action Items
    
    /// Subscribe to action items for a conversation
    /// - Parameters:
    ///   - conversationId: Conversation ID
    ///   - currentUserId: Current user ID (to filter items created by this user only)
    func subscribeToActionItems(conversationId: String, currentUserId: String) {
        // Clean up previous listener
        listener?.remove()
        
        // CRITICAL: Filter by createdBy to show only items created by current user
        // This prevents action items from syncing across all participants
        // (similar to how summaries are filtered by triggeredBy)
        let itemsRef = db.collection("conversations")
            .document(conversationId)
            .collection("actionItems")
            .whereField("createdBy", isEqualTo: currentUserId)
            .order(by: "createdAt", descending: true)
        
        listener = itemsRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error loading action items: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else {
                Task { @MainActor in
                    self.actionItems = []
                }
                return
            }
            
            let items = documents.compactMap { doc -> ActionItem? in
                try? doc.data(as: ActionItem.self)
            }
            
            Task { @MainActor in
                self.actionItems = items
                print("✅ Loaded \(items.count) action items (filtered by createdBy: \(currentUserId))")
            }
        }
    }
    
    // MARK: - Extract Action Items
    
    /// Extract action items from conversation using AI
    /// - Parameters:
    ///   - conversationId: Conversation ID
    ///   - currentUserId: Current user ID
    func extractActionItems(conversationId: String, currentUserId: String) async {
        isExtracting = true
        errorMessage = nil
        
        print("🔄 Extracting action items from conversation: \(conversationId)")
        
        do {
            let result = try await functions.httpsCallable("extractActionItems").call([
                "conversationId": conversationId
            ])
            
            guard let data = result.data as? [String: Any] else {
                throw ActionItemError.invalidResponse
            }
            
            let itemCount = data["itemCount"] as? Int ?? 0
            
            isExtracting = false
            print("✅ Extracted \(itemCount) action items")
            
        } catch {
            isExtracting = false
            errorMessage = "Failed to extract action items: \(error.localizedDescription)"
            print("❌ Failed to extract action items: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Create Action Item
    
    /// Create new action item manually
    /// - Parameters:
    ///   - conversationId: Conversation ID
    ///   - title: Task title
    ///   - assignee: Optional assignee name
    ///   - dueDate: Optional due date
    ///   - currentUserId: Current user ID
    func createActionItem(
        conversationId: String,
        title: String,
        assignee: String?,
        dueDate: Date?,
        currentUserId: String
    ) async {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Title cannot be empty"
            return
        }
        
        let itemRef = db.collection("conversations")
            .document(conversationId)
            .collection("actionItems")
            .document()
        
        let item = ActionItem(
            id: itemRef.documentID,
            conversationId: conversationId,
            title: title,
            assignee: assignee,
            dueDate: dueDate,
            sourceMsgIds: [],
            confidence: 1.0,  // Manually created = 100% confidence
            completed: false,
            createdAt: Date(),
            createdBy: currentUserId,
            updatedAt: Date()
        )
        
        do {
            try await itemRef.setData(item.toDictionary())
            print("✅ Action item created: \(title)")
        } catch {
            errorMessage = "Failed to create action item: \(error.localizedDescription)"
            print("❌ Failed to create action item: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Update Action Item
    
    /// Update existing action item
    /// - Parameters:
    ///   - item: Action item to update
    ///   - conversationId: Conversation ID
    func updateActionItem(_ item: ActionItem, conversationId: String) async {
        let itemRef = db.collection("conversations")
            .document(conversationId)
            .collection("actionItems")
            .document(item.id)
        
        var updatedItem = item
        updatedItem.updatedAt = Date()
        
        do {
            try await itemRef.updateData([
                "title": updatedItem.title,
                "assignee": updatedItem.assignee ?? NSNull(),
                "dueDate": updatedItem.dueDate as Any,
                "completed": updatedItem.completed,
                "updatedAt": updatedItem.updatedAt
            ])
            
            print("✅ Action item updated: \(item.title)")
        } catch {
            errorMessage = "Failed to update action item: \(error.localizedDescription)"
            print("❌ Failed to update action item: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Toggle Completion
    
    /// Toggle action item completion status
    /// - Parameters:
    ///   - item: Action item to toggle
    ///   - conversationId: Conversation ID
    func toggleCompletion(_ item: ActionItem, conversationId: String) async {
        var updatedItem = item
        updatedItem.completed.toggle()
        await updateActionItem(updatedItem, conversationId: conversationId)
    }
    
    // MARK: - Delete Action Item
    
    /// Delete action item
    /// - Parameters:
    ///   - item: Action item to delete
    ///   - conversationId: Conversation ID
    func deleteActionItem(_ item: ActionItem, conversationId: String) async {
        let itemRef = db.collection("conversations")
            .document(conversationId)
            .collection("actionItems")
            .document(item.id)
        
        do {
            try await itemRef.delete()
            print("✅ Action item deleted: \(item.title)")
        } catch {
            errorMessage = "Failed to delete action item: \(error.localizedDescription)"
            print("❌ Failed to delete action item: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        listener?.remove()
        actionItems = []
    }
    
    deinit {
        listener?.remove()
    }
}

// MARK: - Action Item Errors

enum ActionItemError: LocalizedError {
    case invalidResponse
    case emptyTitle
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .emptyTitle:
            return "Action item title cannot be empty"
        }
    }
}

