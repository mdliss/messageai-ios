//
//  ConversationEntity+CoreDataProperties.swift
//  messageAI
//
//  Created by MessageAI Team
//

import Foundation
import CoreData

extension ConversationEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ConversationEntity> {
        return NSFetchRequest<ConversationEntity>(entityName: "ConversationEntity")
    }
    
    @NSManaged public var id: String?
    @NSManaged public var type: String?
    @NSManaged public var participantIds: String?
    @NSManaged public var participantDetailsJSON: String?
    @NSManaged public var lastMessageText: String?
    @NSManaged public var lastMessageTimestamp: Date?
    @NSManaged public var unreadCount: Int32
    @NSManaged public var updatedAt: Date?
    @NSManaged public var groupName: String?
    @NSManaged public var messages: NSSet?
    
}

// MARK: Generated accessors for messages
extension ConversationEntity {
    
    @objc(addMessagesObject:)
    @NSManaged public func addToMessages(_ value: MessageEntity)
    
    @objc(removeMessagesObject:)
    @NSManaged public func removeFromMessages(_ value: MessageEntity)
    
    @objc(addMessages:)
    @NSManaged public func addToMessages(_ values: NSSet)
    
    @objc(removeMessages:)
    @NSManaged public func removeFromMessages(_ values: NSSet)
    
}

extension ConversationEntity: Identifiable {
    
}

