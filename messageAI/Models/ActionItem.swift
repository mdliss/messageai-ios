//
//  ActionItem.swift
//  messageAI
//
//  Created by MessageAI Team
//  Action item model for task tracking
//

import Foundation
import SwiftUI

/// Action item model representing a task extracted from conversation
struct ActionItem: Codable, Identifiable, Equatable {
    let id: String
    let conversationId: String
    var title: String
    var assignee: String?
    var dueDate: Date?
    let sourceMsgIds: [String]
    var confidence: Double
    var completed: Bool
    let createdAt: Date
    let createdBy: String
    var updatedAt: Date
    
    /// Initialize action item
    init(id: String = UUID().uuidString,
         conversationId: String,
         title: String,
         assignee: String? = nil,
         dueDate: Date? = nil,
         sourceMsgIds: [String] = [],
         confidence: Double = 1.0,
         completed: Bool = false,
         createdAt: Date = Date(),
         createdBy: String,
         updatedAt: Date = Date()) {
        self.id = id
        self.conversationId = conversationId
        self.title = title
        self.assignee = assignee
        self.dueDate = dueDate
        self.sourceMsgIds = sourceMsgIds
        self.confidence = confidence
        self.completed = completed
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.updatedAt = updatedAt
    }
    
    /// Convert to Firestore dictionary
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "conversationId": conversationId,
            "title": title,
            "sourceMsgIds": sourceMsgIds,
            "confidence": confidence,
            "completed": completed,
            "createdAt": createdAt,
            "createdBy": createdBy,
            "updatedAt": updatedAt
        ]
        
        if let assignee = assignee {
            dict["assignee"] = assignee
        }
        if let dueDate = dueDate {
            dict["dueDate"] = dueDate
        }
        
        return dict
    }
    
    /// Display text for due date
    var dueDateText: String? {
        guard let dueDate = dueDate else {
            return nil
        }
        
        let calendar = Calendar.current
        if calendar.isDateInToday(dueDate) {
            return "today"
        } else if calendar.isDateInTomorrow(dueDate) {
            return "tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: dueDate)
        }
    }
    
    /// Status icon name
    var statusIcon: String {
        completed ? "checkmark.circle.fill" : "circle"
    }
    
    /// Status color
    var statusColor: Color {
        completed ? .green : .gray
    }
}

