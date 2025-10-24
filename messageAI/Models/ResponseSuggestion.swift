//
//  ResponseSuggestion.swift
//  messageAI
//
//  Advanced AI Feature: Smart Response Suggestions
//  Model representing AI-generated response suggestions for managers
//

import Foundation
import SwiftUI
import FirebaseFirestore

/// Type of response suggestion
enum SuggestionType: String, Codable {
    case approve
    case decline
    case conditional
    case delegate
    
    /// Color associated with suggestion type
    var color: Color {
        switch self {
        case .approve: return .green
        case .decline: return .red
        case .conditional: return .orange
        case .delegate: return .blue
        }
    }
    
    /// Icon for suggestion type
    var icon: String {
        switch self {
        case .approve: return "checkmark.circle.fill"
        case .decline: return "xmark.circle.fill"
        case .conditional: return "questionmark.circle.fill"
        case .delegate: return "arrow.right.circle.fill"
        }
    }
    
    /// Display name for suggestion type
    var displayName: String {
        switch self {
        case .approve: return "approve"
        case .decline: return "decline"
        case .conditional: return "ask more"
        case .delegate: return "delegate"
        }
    }
}

/// AI-generated response suggestion
struct ResponseSuggestion: Identifiable, Codable, Equatable {
    let id: String
    let text: String
    let type: SuggestionType
    let reasoning: String
    let confidence: Double
    
    /// Initialize response suggestion
    init(id: String = UUID().uuidString,
         text: String,
         type: SuggestionType,
         reasoning: String,
         confidence: Double) {
        self.id = id
        self.text = text
        self.type = type
        self.reasoning = reasoning
        self.confidence = confidence
    }
    
    /// Initialize from Firestore dictionary
    init?(from dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let text = dict["text"] as? String,
              let typeStr = dict["type"] as? String,
              let type = SuggestionType(rawValue: typeStr),
              let reasoning = dict["reasoning"] as? String,
              let confidence = dict["confidence"] as? Double else {
            return nil
        }
        
        self.id = id
        self.text = text
        self.type = type
        self.reasoning = reasoning
        self.confidence = confidence
    }
    
    /// Convert to Firestore dictionary
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "text": text,
            "type": type.rawValue,
            "reasoning": reasoning,
            "confidence": confidence
        ]
    }
}

/// Response suggestions cache (stored with message)
struct ResponseSuggestionsCache: Codable {
    let generatedAt: Date
    let expiresAt: Date
    let options: [ResponseSuggestion]
    
    /// Initialize suggestions cache
    init(generatedAt: Date = Date(),
         expiresAt: Date? = nil,
         options: [ResponseSuggestion]) {
        self.generatedAt = generatedAt
        self.expiresAt = expiresAt ?? Date().addingTimeInterval(300) // 5 minutes
        self.options = options
    }
    
    /// Check if cache is expired
    var isExpired: Bool {
        return Date() > expiresAt
    }
    
    /// Initialize from Firestore dictionary
    init?(from dict: [String: Any]) {
        guard let generatedAtTimestamp = dict["generatedAt"] as? Timestamp,
              let expiresAtTimestamp = dict["expiresAt"] as? Timestamp,
              let optionsArray = dict["options"] as? [[String: Any]] else {
            return nil
        }
        
        self.generatedAt = generatedAtTimestamp.dateValue()
        self.expiresAt = expiresAtTimestamp.dateValue()
        
        // Parse options array
        self.options = optionsArray.compactMap { ResponseSuggestion(from: $0) }
        
        // Require at least one option
        guard !self.options.isEmpty else {
            return nil
        }
    }
    
    /// Convert to Firestore dictionary
    func toDictionary() -> [String: Any] {
        return [
            "generatedAt": generatedAt,
            "expiresAt": expiresAt,
            "options": options.map { $0.toDictionary() }
        ]
    }
}

/// Suggestion usage feedback (for learning)
struct SuggestionFeedback: Codable {
    let wasShown: Bool
    var wasUsed: Bool
    var selectedOptionId: String?
    var wasEdited: Bool
    var userRating: UserRating?
    let createdAt: Date
    
    enum UserRating: String, Codable {
        case helpful
        case notHelpful = "not_helpful"
    }
    
    /// Initialize suggestion feedback
    init(wasShown: Bool,
         wasUsed: Bool = false,
         selectedOptionId: String? = nil,
         wasEdited: Bool = false,
         userRating: UserRating? = nil,
         createdAt: Date = Date()) {
        self.wasShown = wasShown
        self.wasUsed = wasUsed
        self.selectedOptionId = selectedOptionId
        self.wasEdited = wasEdited
        self.userRating = userRating
        self.createdAt = createdAt
    }
    
    /// Initialize from Firestore dictionary
    init?(from dict: [String: Any]) {
        guard let wasShown = dict["wasShown"] as? Bool,
              let createdAtTimestamp = dict["createdAt"] as? Timestamp else {
            return nil
        }
        
        self.wasShown = wasShown
        self.wasUsed = dict["wasUsed"] as? Bool ?? false
        self.selectedOptionId = dict["selectedOptionId"] as? String
        self.wasEdited = dict["wasEdited"] as? Bool ?? false
        self.createdAt = createdAtTimestamp.dateValue()
        
        if let ratingStr = dict["userRating"] as? String {
            self.userRating = UserRating(rawValue: ratingStr)
        } else {
            self.userRating = nil
        }
    }
    
    /// Convert to Firestore dictionary
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "wasShown": wasShown,
            "wasUsed": wasUsed,
            "wasEdited": wasEdited,
            "createdAt": createdAt
        ]
        
        if let selectedOptionId = selectedOptionId {
            dict["selectedOptionId"] = selectedOptionId
        }
        
        if let userRating = userRating {
            dict["userRating"] = userRating.rawValue
        }
        
        return dict
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension ResponseSuggestion {
    /// Sample suggestion for previews
    static let sampleApprove = ResponseSuggestion(
        text: "Yes, let's move the deadline to Friday the 25th. Please update the team and adjust the project timeline accordingly.",
        type: .approve,
        reasoning: "Approves request and provides clear next steps",
        confidence: 0.92
    )
    
    static let sampleConditional = ResponseSuggestion(
        text: "What's causing the delay on the design work? If it's just for polish we can extend, but if there are blockers we need to discuss in tomorrow's standup.",
        type: .conditional,
        reasoning: "Asks clarifying question before making decision",
        confidence: 0.88
    )
    
    static let sampleDecline = ResponseSuggestion(
        text: "We need to keep the original deadline because stakeholders are expecting delivery Tuesday. What support or resources do you need to make it happen?",
        type: .decline,
        reasoning: "Declines request but offers support",
        confidence: 0.85
    )
    
    static let sampleDelegate = ResponseSuggestion(
        text: "Let me check with stakeholders on Monday. In the meantime can you send me a revised timeline showing the new milestones?",
        type: .delegate,
        reasoning: "Delegates decision and requests more information",
        confidence: 0.80
    )
    
    /// Sample array of suggestions
    static let samples = [sampleApprove, sampleConditional, sampleDecline, sampleDelegate]
}

extension ResponseSuggestionsCache {
    /// Sample cache for previews
    static let sample = ResponseSuggestionsCache(
        options: ResponseSuggestion.samples
    )
}
#endif

