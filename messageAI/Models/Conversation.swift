//
//  Conversation.swift
//  messageAI
//
//  Created by MessageAI Team
//  Conversation model matching Firestore schema
//

import Foundation

/// Conversation model representing a chat conversation
struct Conversation: Codable, Identifiable, Equatable {
    let id: String
    let type: ConversationType
    let participantIds: [String]
    var participantDetails: [String: ParticipantDetail]
    var lastMessage: LastMessage?
    var unreadCount: [String: Int]
    let createdAt: Date
    var updatedAt: Date
    
    // Group chat specific
    var groupName: String?
    var groupPhotoURL: String?
    var adminIds: [String]?
    
    /// Initialize conversation
    init(id: String = UUID().uuidString,
         type: ConversationType,
         participantIds: [String],
         participantDetails: [String: ParticipantDetail] = [:],
         lastMessage: LastMessage? = nil,
         unreadCount: [String: Int] = [:],
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         groupName: String? = nil,
         groupPhotoURL: String? = nil,
         adminIds: [String]? = nil) {
        self.id = id
        self.type = type
        self.participantIds = participantIds
        self.participantDetails = participantDetails
        self.lastMessage = lastMessage
        self.unreadCount = unreadCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.groupName = groupName
        self.groupPhotoURL = groupPhotoURL
        self.adminIds = adminIds
    }
    
    /// Convert to Firestore dictionary
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "type": type.rawValue,
            "participantIds": participantIds,
            "createdAt": createdAt,
            "updatedAt": updatedAt,
            "unreadCount": unreadCount
        ]
        
        // Add participant details
        let participantDetailsDict = participantDetails.mapValues { $0.toDictionary() }
        dict["participantDetails"] = participantDetailsDict
        
        // Add last message if exists
        if let lastMessage = lastMessage {
            dict["lastMessage"] = lastMessage.toDictionary()
        }
        
        // Add group-specific fields
        if let groupName = groupName {
            dict["groupName"] = groupName
        }
        if let groupPhotoURL = groupPhotoURL {
            dict["groupPhotoURL"] = groupPhotoURL
        }
        if let adminIds = adminIds {
            dict["adminIds"] = adminIds
        }
        
        return dict
    }
    
    /// Get display name for conversation
    /// - Parameter currentUserId: Current user ID
    /// - Returns: Display name string
    func displayName(for currentUserId: String) -> String {
        if type == .group {
            // For groups, use group name or generate from participants
            if let groupName = groupName {
                return groupName
            }
            
            // Generate name from participants (exclude current user)
            let otherParticipants = participantIds.filter { $0 != currentUserId }
            let names = otherParticipants.prefix(2).compactMap { participantDetails[$0]?.displayName }
            
            if otherParticipants.count > 2 {
                return "\(names.joined(separator: ", ")), +\(otherParticipants.count - 2)"
            } else {
                return names.joined(separator: ", ")
            }
        } else {
            // For direct chats, show other participant's name
            let otherUserId = participantIds.first { $0 != currentUserId }
            return participantDetails[otherUserId ?? ""]?.displayName ?? "Unknown"
        }
    }
}

/// Conversation type enum
enum ConversationType: String, Codable {
    case direct
    case group
}

/// Participant detail in a conversation
struct ParticipantDetail: Codable, Equatable {
    let displayName: String
    let photoURL: String?
    
    init(displayName: String, photoURL: String? = nil) {
        self.displayName = displayName
        self.photoURL = photoURL
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["displayName": displayName]
        if let photoURL = photoURL {
            dict["photoURL"] = photoURL
        }
        return dict
    }
}

/// Last message in a conversation
struct LastMessage: Codable, Equatable {
    let text: String
    let senderId: String
    let timestamp: Date
    
    init(text: String, senderId: String, timestamp: Date) {
        self.text = text
        self.senderId = senderId
        self.timestamp = timestamp
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "text": text,
            "senderId": senderId,
            "timestamp": timestamp
        ]
    }
}

