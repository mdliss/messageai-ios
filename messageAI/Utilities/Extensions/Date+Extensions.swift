//
//  Date+Extensions.swift
//  messageAI
//
//  Created by MessageAI Team
//  Date utility extensions
//

import Foundation

extension Date {
    /// Get relative time string (e.g., "5m ago", "2h ago", "Yesterday")
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Check if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// Check if date is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
    
    /// Format as time string (e.g., "2:30 PM")
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    /// Format as date string (e.g., "Oct 21, 2025")
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: self)
    }
}

