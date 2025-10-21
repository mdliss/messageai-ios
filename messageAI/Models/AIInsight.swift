//
//  AIInsight.swift
//  messageAI
//
//  Created by MessageAI Team
//  AI insight model for AI-generated features
//

import Foundation

/// AI insight model for AI-generated content
struct AIInsight: Codable, Identifiable, Equatable {
    let id: String
    let conversationId: String
    let type: InsightType
    let content: String
    let metadata: InsightMetadata?
    let messageIds: [String]
    let triggeredBy: String
    let createdAt: Date
    let expiresAt: Date?
    var userFeedback: String?
    var dismissed: Bool
    
    /// Initialize AI insight
    init(id: String = UUID().uuidString,
         conversationId: String,
         type: InsightType,
         content: String,
         metadata: InsightMetadata? = nil,
         messageIds: [String] = [],
         triggeredBy: String,
         createdAt: Date = Date(),
         expiresAt: Date? = nil,
         userFeedback: String? = nil,
         dismissed: Bool = false) {
        self.id = id
        self.conversationId = conversationId
        self.type = type
        self.content = content
        self.metadata = metadata
        self.messageIds = messageIds
        self.triggeredBy = triggeredBy
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.userFeedback = userFeedback
        self.dismissed = dismissed
    }
    
    /// Convert to Firestore dictionary
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "conversationId": conversationId,
            "type": type.rawValue,
            "content": content,
            "messageIds": messageIds,
            "triggeredBy": triggeredBy,
            "createdAt": createdAt,
            "dismissed": dismissed
        ]
        
        if let metadata = metadata {
            dict["metadata"] = metadata.toDictionary()
        }
        if let expiresAt = expiresAt {
            dict["expiresAt"] = expiresAt
        }
        if let userFeedback = userFeedback {
            dict["userFeedback"] = userFeedback
        }
        
        return dict
    }
    
    /// Get icon for insight type
    var icon: String {
        switch type {
        case .summary:
            return "doc.text"
        case .actionItems:
            return "checklist"
        case .decision:
            return "checkmark.circle"
        case .priority:
            return "exclamationmark.triangle"
        case .suggestion:
            return "lightbulb"
        }
    }
    
    /// Get title for insight type
    var title: String {
        switch type {
        case .summary:
            return "thread summary"
        case .actionItems:
            return "action items"
        case .decision:
            return "decision logged"
        case .priority:
            return "urgent message"
        case .suggestion:
            return "suggestion"
        }
    }
}

/// Insight type enum
enum InsightType: String, Codable, CaseIterable {
    case summary
    case actionItems = "action_items"
    case decision
    case priority
    case suggestion
}

/// Metadata for AI insights
struct InsightMetadata: Codable, Equatable {
    var bulletPoints: Int?
    var messageCount: Int?
    var approvedBy: [String]?
    var action: String?
    var confidence: Double?
    
    init(bulletPoints: Int? = nil,
         messageCount: Int? = nil,
         approvedBy: [String]? = nil,
         action: String? = nil,
         confidence: Double? = nil) {
        self.bulletPoints = bulletPoints
        self.messageCount = messageCount
        self.approvedBy = approvedBy
        self.action = action
        self.confidence = confidence
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        
        if let bulletPoints = bulletPoints {
            dict["bulletPoints"] = bulletPoints
        }
        if let messageCount = messageCount {
            dict["messageCount"] = messageCount
        }
        if let approvedBy = approvedBy {
            dict["approvedBy"] = approvedBy
        }
        if let action = action {
            dict["action"] = action
        }
        if let confidence = confidence {
            dict["confidence"] = confidence
        }
        
        return dict
    }
}

