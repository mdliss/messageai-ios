//
//  Message.swift
//  messageAI
//
//  Created by MessageAI Team
//  Message model matching Firestore schema
//

import Foundation

/// Message model representing a chat message
struct Message: Codable, Identifiable, Equatable, Hashable {
    var id: String
    let conversationId: String
    let senderId: String
    let senderName: String
    let senderPhotoURL: String?
    let senderAvatarType: AvatarType?
    let senderAvatarId: String?
    
    let type: MessageType
    let text: String
    let imageURL: String?
    let voiceURL: String?  // NEW: Firebase Storage path for voice memo
    var transcription: String?  // NEW: Transcription from OpenAI Whisper
    var duration: TimeInterval?  // NEW: Voice memo duration in seconds

    let createdAt: Date

    var status: MessageStatus
    var deliveredTo: [String]
    var readBy: [String]

    var localId: String?
    var isSynced: Bool
    var priority: MessagePriority?  // NEW: Priority level (urgent, high, normal)
    var embedding: [Float]?  // NEW: OpenAI text-embedding-3-small (1536 floats)
    var mentionedUserIds: [String]?  // NEW: User IDs mentioned in this message
    
    /// Initialize message
    init(id: String = UUID().uuidString,
         conversationId: String,
         senderId: String,
         senderName: String,
         senderPhotoURL: String? = nil,
         senderAvatarType: AvatarType? = nil,
         senderAvatarId: String? = nil,
         type: MessageType = .text,
         text: String = "",
         imageURL: String? = nil,
         voiceURL: String? = nil,
         transcription: String? = nil,
         duration: TimeInterval? = nil,
         createdAt: Date = Date(),
         status: MessageStatus = .sending,
         deliveredTo: [String] = [],
         readBy: [String] = [],
         localId: String? = nil,
         isSynced: Bool = false,
         priority: MessagePriority? = nil,
         embedding: [Float]? = nil,
         mentionedUserIds: [String]? = nil) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.senderName = senderName
        self.senderPhotoURL = senderPhotoURL
        self.senderAvatarType = senderAvatarType
        self.senderAvatarId = senderAvatarId
        self.type = type
        self.text = text
        self.imageURL = imageURL
        self.voiceURL = voiceURL
        self.transcription = transcription
        self.duration = duration
        self.createdAt = createdAt
        self.status = status
        self.deliveredTo = deliveredTo
        self.readBy = readBy
        self.localId = localId
        self.isSynced = isSynced
        self.priority = priority
        self.embedding = embedding
        self.mentionedUserIds = mentionedUserIds
    }
    
    /// Convert to Firestore dictionary
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "conversationId": conversationId,
            "senderId": senderId,
            "senderName": senderName,
            "type": type.rawValue,
            "text": text,
            "createdAt": createdAt,
            "status": status.rawValue,
            "deliveredTo": deliveredTo,
            "readBy": readBy,
            "isSynced": isSynced
        ]
        
        if let senderPhotoURL = senderPhotoURL {
            dict["senderPhotoURL"] = senderPhotoURL
        }
        if let senderAvatarType = senderAvatarType {
            dict["senderAvatarType"] = senderAvatarType.rawValue
        }
        if let senderAvatarId = senderAvatarId {
            dict["senderAvatarId"] = senderAvatarId
        }
        if let imageURL = imageURL {
            dict["imageURL"] = imageURL
        }
        if let localId = localId {
            dict["localId"] = localId
        }
        if let priority = priority {
            dict["priority"] = priority.rawValue
        }
        if let embedding = embedding {
            dict["embedding"] = embedding
        }
        if let mentionedUserIds = mentionedUserIds {
            dict["mentionedUserIds"] = mentionedUserIds
        }
        if let voiceURL = voiceURL {
            dict["voiceURL"] = voiceURL
        }
        if let transcription = transcription {
            dict["transcription"] = transcription
        }
        if let duration = duration {
            dict["duration"] = duration
        }

        return dict
    }
    
    /// Check if message is from current user
    /// - Parameter userId: Current user ID
    /// - Returns: True if message is from current user
    func isFromCurrentUser(userId: String) -> Bool {
        return senderId == userId
    }
    
    /// Check if message has been read
    /// - Returns: True if message has been read
    func isRead() -> Bool {
        return status == .read || !readBy.isEmpty
    }
    
    /// Preview text for display in conversation list
    var previewText: String {
        switch type {
        case .text:
            return text
        case .image:
            return "📷 Photo"
        case .voice:
            if let transcription = transcription, !transcription.isEmpty {
                return "🎤 \(transcription)"
            }
            return "🎤 Voice message"
        }
    }
}

/// Message type enum
enum MessageType: String, Codable, CaseIterable {
    case text
    case image
    case voice
}

/// Message status enum
enum MessageStatus: String, Codable, CaseIterable {
    case sending
    case sent
    case delivered
    case read
    case failed
}

/// Message priority enum
enum MessagePriority: String, Codable, CaseIterable {
    case urgent   // Red hazard symbol - critical/emergency
    case high     // Yellow circle - important/needs attention
    case normal   // No indicator - regular message
}

