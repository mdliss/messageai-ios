//
//  MessageEntity+CoreDataProperties.swift
//  messageAI
//
//  Created by MessageAI Team
//

import Foundation
import CoreData

extension MessageEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MessageEntity> {
        return NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
    }
    
    @NSManaged public var id: String?
    @NSManaged public var conversationId: String?
    @NSManaged public var senderId: String?
    @NSManaged public var senderName: String?
    @NSManaged public var senderPhotoURL: String?
    @NSManaged public var type: String?
    @NSManaged public var text: String?
    @NSManaged public var imageURL: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var status: String?
    @NSManaged public var deliveredTo: String?
    @NSManaged public var readBy: String?
    @NSManaged public var localId: String?
    @NSManaged public var isSynced: Bool
    @NSManaged public var priorityString: String?  // Changed from Bool to String
    @NSManaged public var conversation: ConversationEntity?
    
}

extension MessageEntity: Identifiable {
    
}

