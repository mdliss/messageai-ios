//
//  Blocker.swift
//  messageAI
//
//  Advanced AI Feature: Proactive Blocker Detection
//  Models for detected blockers and alerts
//

import Foundation
import SwiftUI
import FirebaseFirestore

/// Type of blocker detected
enum BlockerType: String, Codable {
    case explicit
    case approval
    case resource
    case technical
    case people
    case timeBased = "time_based"
    
    var displayName: String {
        switch self {
        case .explicit: return "explicitly stated"
        case .approval: return "waiting for approval"
        case .resource: return "missing resource"
        case .technical: return "technical issue"
        case .people: return "waiting for person"
        case .timeBased: return "time based"
        }
    }
}

/// Severity level of blocker
enum BlockerSeverity: String, Codable, Comparable {
    case critical
    case high
    case medium
    case low
    
    /// Color for severity indicator
    var color: Color {
        switch self {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        }
    }
    
    /// Icon for severity
    var icon: String {
        switch self {
        case .critical: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.circle.fill"
        case .medium: return "exclamationmark.circle"
        case .low: return "info.circle"
        }
    }
    
    /// Display name
    var displayName: String {
        return rawValue.uppercased()
    }
    
    /// Rank for sorting (critical = 0, low = 3)
    var rank: Int {
        switch self {
        case .critical: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }
    
    // Comparable conformance
    static func < (lhs: BlockerSeverity, rhs: BlockerSeverity) -> Bool {
        return lhs.rank < rhs.rank
    }
}

/// Status of blocker
enum BlockerStatus: String, Codable {
    case active
    case resolved
    case snoozed
    case falsePositive = "false_positive"
    
    var displayName: String {
        switch self {
        case .active: return "active"
        case .resolved: return "resolved"
        case .snoozed: return "snoozed"
        case .falsePositive: return "false positive"
        }
    }
}

/// Detected blocker
struct Blocker: Identifiable, Codable, Equatable {
    let id: String
    let detectedAt: Date
    let messageId: String
    let blockedUserId: String
    let blockedUserName: String
    let blockerDescription: String
    let blockerType: BlockerType
    let severity: BlockerSeverity
    var status: BlockerStatus
    let suggestedActions: [String]
    let conversationId: String
    
    var resolvedAt: Date?
    var resolvedBy: String?
    var resolutionNotes: String?
    var snoozedUntil: Date?
    
    let confidence: Double
    var managerMarkedFalsePositive: Bool
    
    /// Time elapsed since detection
    var timeElapsed: String {
        let interval = Date().timeIntervalSince(detectedAt)
        let hours = Int(interval) / 3600
        
        if hours < 1 {
            let minutes = Int(interval) / 60
            return "\(minutes) min ago"
        } else if hours < 24 {
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = hours / 24
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
    
    /// Initialize blocker
    init(id: String = UUID().uuidString,
         detectedAt: Date = Date(),
         messageId: String,
         blockedUserId: String,
         blockedUserName: String,
         blockerDescription: String,
         blockerType: BlockerType,
         severity: BlockerSeverity,
         status: BlockerStatus = .active,
         suggestedActions: [String],
         conversationId: String,
         resolvedAt: Date? = nil,
         resolvedBy: String? = nil,
         resolutionNotes: String? = nil,
         snoozedUntil: Date? = nil,
         confidence: Double = 0.8,
         managerMarkedFalsePositive: Bool = false) {
        self.id = id
        self.detectedAt = detectedAt
        self.messageId = messageId
        self.blockedUserId = blockedUserId
        self.blockedUserName = blockedUserName
        self.blockerDescription = blockerDescription
        self.blockerType = blockerType
        self.severity = severity
        self.status = status
        self.suggestedActions = suggestedActions
        self.conversationId = conversationId
        self.resolvedAt = resolvedAt
        self.resolvedBy = resolvedBy
        self.resolutionNotes = resolutionNotes
        self.snoozedUntil = snoozedUntil
        self.confidence = confidence
        self.managerMarkedFalsePositive = managerMarkedFalsePositive
    }
    
    /// Initialize from Firestore document data
    init?(from data: [String: Any]) {
        guard let id = data["id"] as? String,
              let messageId = data["messageId"] as? String,
              let blockedUserId = data["blockedUserId"] as? String,
              let blockedUserName = data["blockedUserName"] as? String,
              let blockerDescription = data["blockerDescription"] as? String,
              let blockerTypeStr = data["blockerType"] as? String,
              let blockerType = BlockerType(rawValue: blockerTypeStr),
              let severityStr = data["severity"] as? String,
              let severity = BlockerSeverity(rawValue: severityStr),
              let statusStr = data["status"] as? String,
              let status = BlockerStatus(rawValue: statusStr),
              let conversationId = data["conversationId"] as? String,
              let confidence = data["confidence"] as? Double else {
            return nil
        }
        
        self.id = id
        self.messageId = messageId
        self.blockedUserId = blockedUserId
        self.blockedUserName = blockedUserName
        self.blockerDescription = blockerDescription
        self.blockerType = blockerType
        self.severity = severity
        self.status = status
        self.conversationId = conversationId
        self.confidence = confidence
        
        // Parse timestamps
        if let detectedAtTimestamp = data["detectedAt"] as? Timestamp {
            self.detectedAt = detectedAtTimestamp.dateValue()
        } else {
            self.detectedAt = Date()
        }
        
        if let resolvedAtTimestamp = data["resolvedAt"] as? Timestamp {
            self.resolvedAt = resolvedAtTimestamp.dateValue()
        } else {
            self.resolvedAt = nil
        }
        
        if let snoozedUntilTimestamp = data["snoozedUntil"] as? Timestamp {
            self.snoozedUntil = snoozedUntilTimestamp.dateValue()
        } else {
            self.snoozedUntil = nil
        }
        
        // Parse suggested actions
        self.suggestedActions = data["suggestedActions"] as? [String] ?? []
        
        // Parse optional fields
        self.resolvedBy = data["resolvedBy"] as? String
        self.resolutionNotes = data["resolutionNotes"] as? String
        self.managerMarkedFalsePositive = data["managerMarkedFalsePositive"] as? Bool ?? false
    }
    
    /// Convert to Firestore dictionary
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "detectedAt": detectedAt,
            "messageId": messageId,
            "blockedUserId": blockedUserId,
            "blockedUserName": blockedUserName,
            "blockerDescription": blockerDescription,
            "blockerType": blockerType.rawValue,
            "severity": severity.rawValue,
            "status": status.rawValue,
            "suggestedActions": suggestedActions,
            "conversationId": conversationId,
            "confidence": confidence,
            "managerMarkedFalsePositive": managerMarkedFalsePositive
        ]
        
        if let resolvedAt = resolvedAt {
            dict["resolvedAt"] = resolvedAt
        }
        
        if let resolvedBy = resolvedBy {
            dict["resolvedBy"] = resolvedBy
        }
        
        if let resolutionNotes = resolutionNotes {
            dict["resolutionNotes"] = resolutionNotes
        }
        
        if let snoozedUntil = snoozedUntil {
            dict["snoozedUntil"] = snoozedUntil
        }
        
        return dict
    }
}

/// Blocker alert for manager notification
struct BlockerAlert: Identifiable, Codable {
    let id: String
    let blockerId: String
    let conversationId: String
    let severity: BlockerSeverity
    let blockerDescription: String
    let createdAt: Date
    var read: Bool
    var dismissed: Bool
    
    /// Initialize blocker alert
    init(id: String = UUID().uuidString,
         blockerId: String,
         conversationId: String,
         severity: BlockerSeverity,
         blockerDescription: String,
         createdAt: Date = Date(),
         read: Bool = false,
         dismissed: Bool = false) {
        self.id = id
        self.blockerId = blockerId
        self.conversationId = conversationId
        self.severity = severity
        self.blockerDescription = blockerDescription
        self.createdAt = createdAt
        self.read = read
        self.dismissed = dismissed
    }
    
    /// Initialize from Firestore
    init?(from data: [String: Any]) {
        guard let id = data["id"] as? String,
              let blockerId = data["blockerId"] as? String,
              let conversationId = data["conversationId"] as? String,
              let severityStr = data["severity"] as? String,
              let severity = BlockerSeverity(rawValue: severityStr),
              let blockerDescription = data["blockerDescription"] as? String else {
            return nil
        }
        
        self.id = id
        self.blockerId = blockerId
        self.conversationId = conversationId
        self.severity = severity
        self.blockerDescription = blockerDescription
        
        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            self.createdAt = createdAtTimestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
        
        self.read = data["read"] as? Bool ?? false
        self.dismissed = data["dismissed"] as? Bool ?? false
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension Blocker {
    /// Sample blocker for previews
    static let sampleCritical = Blocker(
        messageId: "msg123",
        blockedUserId: "user456",
        blockedUserName: "Sarah Chen",
        blockerDescription: "waiting for production deploy access",
        blockerType: .resource,
        severity: .critical,
        suggestedActions: [
            "escalate to devops lead immediately",
            "grant emergency access"
        ],
        conversationId: "conv789",
        confidence: 0.95
    )
    
    static let sampleHigh = Blocker(
        messageId: "msg124",
        blockedUserId: "user789",
        blockedUserName: "Bob Wilson",
        blockerDescription: "waiting for api auth token from devops",
        blockerType: .people,
        severity: .high,
        suggestedActions: [
            "reach out to devops team",
            "escalate to platform lead"
        ],
        conversationId: "conv789",
        confidence: 0.90
    )
    
    static let samples = [sampleCritical, sampleHigh]
}
#endif

