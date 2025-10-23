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
    var suggestedTimes: String?
    var targetUserId: String?
    var votes: [String: String]?
    var isPoll: Bool?
    var timeOptions: [String]?
    var createdBy: String?
    var finalized: Bool?
    var winningOption: String?
    var winningTime: String?
    var totalVotes: Int?
    var pollId: String?           // NEW: Link to original poll
    var voteCount: Int?            // NEW: Number of votes for winning option
    var consensusReached: Bool?    // NEW: True if all voted same
    var pollStatus: String?        // NEW: "active", "confirmed", "cancelled"
    var confirmedBy: String?       // NEW: userId who confirmed poll
    var confirmedAt: Date?         // NEW: timestamp when confirmed
    var participantIds: [String]?  // NEW: all participant user IDs
    
    init(bulletPoints: Int? = nil,
         messageCount: Int? = nil,
         approvedBy: [String]? = nil,
         action: String? = nil,
         confidence: Double? = nil,
         suggestedTimes: String? = nil,
         targetUserId: String? = nil,
         votes: [String: String]? = nil,
         isPoll: Bool? = nil,
         timeOptions: [String]? = nil,
         createdBy: String? = nil,
         finalized: Bool? = nil,
         winningOption: String? = nil,
         winningTime: String? = nil,
         totalVotes: Int? = nil,
         pollId: String? = nil,
         voteCount: Int? = nil,
         consensusReached: Bool? = nil,
         pollStatus: String? = nil,
         confirmedBy: String? = nil,
         confirmedAt: Date? = nil,
         participantIds: [String]? = nil) {
        self.bulletPoints = bulletPoints
        self.messageCount = messageCount
        self.approvedBy = approvedBy
        self.action = action
        self.confidence = confidence
        self.suggestedTimes = suggestedTimes
        self.targetUserId = targetUserId
        self.votes = votes
        self.isPoll = isPoll
        self.timeOptions = timeOptions
        self.createdBy = createdBy
        self.finalized = finalized
        self.winningOption = winningOption
        self.winningTime = winningTime
        self.totalVotes = totalVotes
        self.pollId = pollId
        self.voteCount = voteCount
        self.consensusReached = consensusReached
        self.pollStatus = pollStatus
        self.confirmedBy = confirmedBy
        self.confirmedAt = confirmedAt
        self.participantIds = participantIds
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
        if let suggestedTimes = suggestedTimes {
            dict["suggestedTimes"] = suggestedTimes
        }
        if let targetUserId = targetUserId {
            dict["targetUserId"] = targetUserId
        }
        if let votes = votes {
            dict["votes"] = votes
        }
        if let isPoll = isPoll {
            dict["isPoll"] = isPoll
        }
        if let timeOptions = timeOptions {
            dict["timeOptions"] = timeOptions
        }
        if let createdBy = createdBy {
            dict["createdBy"] = createdBy
        }
        if let finalized = finalized {
            dict["finalized"] = finalized
        }
        if let winningOption = winningOption {
            dict["winningOption"] = winningOption
        }
        if let winningTime = winningTime {
            dict["winningTime"] = winningTime
        }
        if let totalVotes = totalVotes {
            dict["totalVotes"] = totalVotes
        }
        if let pollId = pollId {
            dict["pollId"] = pollId
        }
        if let voteCount = voteCount {
            dict["voteCount"] = voteCount
        }
        if let consensusReached = consensusReached {
            dict["consensusReached"] = consensusReached
        }
        if let pollStatus = pollStatus {
            dict["pollStatus"] = pollStatus
        }
        if let confirmedBy = confirmedBy {
            dict["confirmedBy"] = confirmedBy
        }
        if let confirmedAt = confirmedAt {
            dict["confirmedAt"] = confirmedAt
        }
        if let participantIds = participantIds {
            dict["participantIds"] = participantIds
        }
        
        return dict
    }
}

