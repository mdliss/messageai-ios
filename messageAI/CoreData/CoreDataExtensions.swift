//
//  CoreDataExtensions.swift
//  messageAI
//
//  Created by MessageAI Team
//  Extensions for Core Data entities
//

import Foundation
import CoreData

// MARK: - MessageEntity Extensions

extension MessageEntity {
    /// Convert MessageEntity to Message model
    func toMessage() -> Message {
        // Parse arrays from JSON strings
        let deliveredToArray = parseStringArray(deliveredTo)
        let readByArray = parseStringArray(readBy)
        
        return Message(
            id: id ?? "",
            conversationId: conversationId ?? "",
            senderId: senderId ?? "",
            senderName: senderName ?? "",
            senderPhotoURL: senderPhotoURL,
            type: MessageType(rawValue: type ?? "text") ?? .text,
            text: text ?? "",
            imageURL: imageURL,
            createdAt: createdAt ?? Date(),
            status: MessageStatus(rawValue: status ?? "sent") ?? .sent,
            deliveredTo: deliveredToArray,
            readBy: readByArray,
            localId: localId,
            isSynced: isSynced,
            priority: priority
        )
    }
    
    /// Update entity from Message model
    func update(from message: Message) {
        self.id = message.id
        self.conversationId = message.conversationId
        self.senderId = message.senderId
        self.senderName = message.senderName
        self.senderPhotoURL = message.senderPhotoURL
        self.type = message.type.rawValue
        self.text = message.text
        self.imageURL = message.imageURL
        self.createdAt = message.createdAt
        self.status = message.status.rawValue
        self.deliveredTo = stringifyArray(message.deliveredTo)
        self.readBy = stringifyArray(message.readBy)
        self.localId = message.localId
        self.isSynced = message.isSynced
        self.priority = message.priority ?? false
    }
    
    /// Parse JSON string array
    private func parseStringArray(_ jsonString: String?) -> [String] {
        guard let jsonString = jsonString,
              let data = jsonString.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }
    
    /// Convert array to JSON string
    private func stringifyArray(_ array: [String]) -> String? {
        guard let data = try? JSONEncoder().encode(array),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }
    
    /// Fetch request for messages in a conversation
    static func fetchRequest(for conversationId: String) -> NSFetchRequest<MessageEntity> {
        let request = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
        request.predicate = NSPredicate(format: "conversationId == %@", conversationId)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return request
    }
    
    /// Fetch request for unsynced messages
    static func unsyncedMessagesFetchRequest() -> NSFetchRequest<MessageEntity> {
        let request = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
        request.predicate = NSPredicate(format: "isSynced == NO")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return request
    }
}

// MARK: - ConversationEntity Extensions

extension ConversationEntity {
    /// Convert ConversationEntity to Conversation model
    func toConversation() -> Conversation {
        // Parse participant IDs from JSON
        let participantIdsArray = parseStringArray(participantIds)
        
        // Parse participant details from JSON
        let participantDetailsDict = parseParticipantDetails(participantDetailsJSON)
        
        // Create last message if available
        var lastMessage: LastMessage? = nil
        if let lastMessageText = lastMessageText,
           let lastMessageTimestamp = lastMessageTimestamp {
            lastMessage = LastMessage(
                text: lastMessageText,
                senderId: "", // Not stored in entity, will be updated from messages
                timestamp: lastMessageTimestamp
            )
        }
        
        return Conversation(
            id: id ?? "",
            type: ConversationType(rawValue: type ?? "direct") ?? .direct,
            participantIds: participantIdsArray,
            participantDetails: participantDetailsDict,
            lastMessage: lastMessage,
            unreadCount: [:], // Will be calculated from messages
            createdAt: Date(), // Not stored in entity
            updatedAt: updatedAt ?? Date(),
            groupName: groupName,
            groupPhotoURL: nil,
            adminIds: nil
        )
    }
    
    /// Update entity from Conversation model
    func update(from conversation: Conversation) {
        self.id = conversation.id
        self.type = conversation.type.rawValue
        self.participantIds = stringifyStringArray(conversation.participantIds)
        self.participantDetailsJSON = stringifyParticipantDetails(conversation.participantDetails)
        self.lastMessageText = conversation.lastMessage?.text
        self.lastMessageTimestamp = conversation.lastMessage?.timestamp
        self.unreadCount = 0 // Will be calculated
        self.updatedAt = conversation.updatedAt
        self.groupName = conversation.groupName
    }
    
    /// Parse JSON string array
    private func parseStringArray(_ jsonString: String?) -> [String] {
        guard let jsonString = jsonString,
              let data = jsonString.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }
    
    /// Convert array to JSON string
    private func stringifyStringArray(_ array: [String]) -> String? {
        guard let data = try? JSONEncoder().encode(array),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }
    
    /// Parse participant details from JSON
    private func parseParticipantDetails(_ jsonString: String?) -> [String: ParticipantDetail] {
        guard let jsonString = jsonString,
              let data = jsonString.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: ParticipantDetail].self, from: data) else {
            return [:]
        }
        return dict
    }
    
    /// Convert participant details to JSON string
    private func stringifyParticipantDetails(_ details: [String: ParticipantDetail]) -> String? {
        guard let data = try? JSONEncoder().encode(details),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }
    
    /// Fetch request for all conversations
    static func allConversationsFetchRequest() -> NSFetchRequest<ConversationEntity> {
        let request = NSFetchRequest<ConversationEntity>(entityName: "ConversationEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        return request
    }
    
    /// Fetch request for a specific conversation
    static func fetchRequest(for conversationId: String) -> NSFetchRequest<ConversationEntity> {
        let request = NSFetchRequest<ConversationEntity>(entityName: "ConversationEntity")
        request.predicate = NSPredicate(format: "id == %@", conversationId)
        request.fetchLimit = 1
        return request
    }
}

