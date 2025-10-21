//
//  TypingIndicator.swift
//  messageAI
//
//  Created by MessageAI Team
//  Typing indicator model for real-time typing status
//

import Foundation

/// Typing indicator model for real-time typing status
struct TypingIndicator: Codable, Identifiable, Equatable {
    let userId: String
    let conversationId: String
    var isTyping: Bool
    let timestamp: Date
    
    var id: String { userId }
    
    /// Initialize typing indicator
    init(userId: String,
         conversationId: String,
         isTyping: Bool = true,
         timestamp: Date = Date()) {
        self.userId = userId
        self.conversationId = conversationId
        self.isTyping = isTyping
        self.timestamp = timestamp
    }
}

