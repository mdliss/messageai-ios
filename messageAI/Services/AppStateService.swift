//
//  AppStateService.swift
//  messageAI
//
//  Created by MessageAI Team
//  Global app state management for tracking current conversation
//

import Foundation
import SwiftUI
import Combine

/// Global app state service for tracking current conversation and other app-wide state
class AppStateService: ObservableObject {
    static let shared = AppStateService()

    @Published var currentConversationId: String? = nil

    init() {}

    /// Set the currently open conversation
    /// - Parameter conversationId: The ID of the currently open conversation, or nil if no conversation is open
    func setCurrentConversation(_ conversationId: String?) {
        print("📱 Current conversation changed: \(conversationId ?? "none")")
        currentConversationId = conversationId
    }

    /// Check if a specific conversation is currently open
    /// - Parameter conversationId: The conversation ID to check
    /// - Returns: True if this conversation is currently open
    func isConversationOpen(_ conversationId: String) -> Bool {
        return currentConversationId == conversationId
    }
}
