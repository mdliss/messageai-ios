//
//  CoreDataService.swift
//  messageAI
//
//  Created by MessageAI Team
//  Service handling all Core Data operations
//

import Foundation
import CoreData

/// Service managing Core Data operations for messages and conversations
class CoreDataService {
    static let shared = CoreDataService()
    
    private let persistenceController = PersistenceController.shared
    
    private var viewContext: NSManagedObjectContext {
        return persistenceController.viewContext
    }
    
    private init() {}
    
    // MARK: - Message Operations
    
    /// Save message to Core Data
    /// - Parameter message: Message to save
    func saveMessage(_ message: Message) {
        let context = viewContext
        
        // Check if message already exists
        let fetchRequest = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
        fetchRequest.predicate = NSPredicate(format: "id == %@", message.id)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            
            let entity: MessageEntity
            if let existingEntity = results.first {
                // Update existing entity
                entity = existingEntity
            } else {
                // Create new entity
                entity = MessageEntity(context: context)
            }
            
            entity.update(from: message)
            
            try context.save()
            print("✅ Message saved to Core Data: \(message.id)")
        } catch {
            print("❌ Failed to save message: \(error.localizedDescription)")
        }
    }
    
    /// Save multiple messages to Core Data
    /// - Parameter messages: Array of messages to save
    func saveMessages(_ messages: [Message]) {
        let context = viewContext
        
        for message in messages {
            let fetchRequest = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
            fetchRequest.predicate = NSPredicate(format: "id == %@", message.id)
            fetchRequest.fetchLimit = 1
            
            do {
                let results = try context.fetch(fetchRequest)
                
                let entity: MessageEntity
                if let existingEntity = results.first {
                    entity = existingEntity
                } else {
                    entity = MessageEntity(context: context)
                }
                
                entity.update(from: message)
            } catch {
                print("❌ Failed to process message \(message.id): \(error.localizedDescription)")
            }
        }
        
        do {
            try context.save()
            print("✅ Saved \(messages.count) messages to Core Data")
        } catch {
            print("❌ Failed to save messages: \(error.localizedDescription)")
        }
    }
    
    /// Fetch messages for a conversation
    /// - Parameters:
    ///   - conversationId: Conversation ID
    ///   - limit: Maximum number of messages to fetch (default: no limit)
    /// - Returns: Array of messages sorted by creation date
    func fetchMessages(conversationId: String, limit: Int? = nil) -> [Message] {
        let fetchRequest = MessageEntity.fetchRequest(for: conversationId)
        
        if let limit = limit {
            fetchRequest.fetchLimit = limit
        }
        
        do {
            let entities = try viewContext.fetch(fetchRequest)
            return entities.map { $0.toMessage() }
        } catch {
            print("❌ Failed to fetch messages: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Update message status
    /// - Parameters:
    ///   - messageId: Message ID
    ///   - status: New status
    func updateMessageStatus(messageId: String, status: MessageStatus) {
        let fetchRequest = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
        fetchRequest.predicate = NSPredicate(format: "id == %@", messageId)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            
            if let entity = results.first {
                entity.status = status.rawValue
                try viewContext.save()
                print("✅ Updated message status: \(messageId) → \(status.rawValue)")
            }
        } catch {
            print("❌ Failed to update message status: \(error.localizedDescription)")
        }
    }
    
    /// Update message sync status
    /// - Parameters:
    ///   - localId: Local message ID
    ///   - serverId: Server-assigned ID
    func updateMessageSync(localId: String, serverId: String) {
        let fetchRequest = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
        fetchRequest.predicate = NSPredicate(format: "localId == %@", localId)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            
            if let entity = results.first {
                entity.id = serverId
                entity.isSynced = true
                try viewContext.save()
                print("✅ Updated message sync: \(localId) → \(serverId)")
            }
        } catch {
            print("❌ Failed to update message sync: \(error.localizedDescription)")
        }
    }
    
    /// Fetch unsynced messages
    /// - Returns: Array of unsynced messages
    func fetchUnsyncedMessages() -> [Message] {
        let fetchRequest = MessageEntity.unsyncedMessagesFetchRequest()
        
        do {
            let entities = try viewContext.fetch(fetchRequest)
            return entities.map { $0.toMessage() }
        } catch {
            print("❌ Failed to fetch unsynced messages: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Delete message from Core Data
    /// - Parameter messageId: Message ID (can be server ID or local ID)
    func deleteMessage(messageId: String) {
        let fetchRequest = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
        // Try to match by id OR localId
        fetchRequest.predicate = NSPredicate(format: "id == %@ OR localId == %@", messageId, messageId)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            
            if let entity = results.first {
                viewContext.delete(entity)
                try viewContext.save()
                print("✅ Deleted message from Core Data: \(messageId)")
            } else {
                print("⚠️ Message not found in Core Data: \(messageId)")
            }
        } catch {
            print("❌ Failed to delete message: \(error.localizedDescription)")
        }
    }
    
    /// Clean up old unsynced messages (for maintenance)
    func cleanupOldUnsyncedMessages(olderThan days: Int = 7) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let fetchRequest = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
        fetchRequest.predicate = NSPredicate(format: "isSynced == NO AND createdAt < %@", cutoffDate as NSDate)
        
        do {
            let oldMessages = try viewContext.fetch(fetchRequest)
            
            for entity in oldMessages {
                viewContext.delete(entity)
            }
            
            try viewContext.save()
            print("✅ Cleaned up \(oldMessages.count) old unsynced messages")
        } catch {
            print("❌ Failed to cleanup old messages: \(error.localizedDescription)")
        }
    }
    
    /// Clear ALL unsynced messages (for testing/debugging)
    func clearAllUnsyncedMessages() {
        let fetchRequest = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
        fetchRequest.predicate = NSPredicate(format: "isSynced == NO")
        
        do {
            let unsyncedMessages = try viewContext.fetch(fetchRequest)
            
            for entity in unsyncedMessages {
                viewContext.delete(entity)
            }
            
            try viewContext.save()
            print("✅ Cleared ALL \(unsyncedMessages.count) unsynced messages from Core Data")
        } catch {
            print("❌ Failed to clear unsynced messages: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Conversation Operations
    
    /// Save conversation to Core Data
    /// - Parameter conversation: Conversation to save
    func saveConversation(_ conversation: Conversation) {
        let context = viewContext
        
        // Check if conversation already exists
        let fetchRequest = NSFetchRequest<ConversationEntity>(entityName: "ConversationEntity")
        fetchRequest.predicate = NSPredicate(format: "id == %@", conversation.id)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            
            let entity: ConversationEntity
            if let existingEntity = results.first {
                entity = existingEntity
            } else {
                entity = ConversationEntity(context: context)
            }
            
            entity.update(from: conversation)
            
            try context.save()
            print("✅ Conversation saved to Core Data: \(conversation.id)")
        } catch {
            print("❌ Failed to save conversation: \(error.localizedDescription)")
        }
    }
    
    /// Fetch all conversations
    /// - Returns: Array of conversations sorted by last message timestamp
    func fetchConversations() -> [Conversation] {
        let fetchRequest = ConversationEntity.allConversationsFetchRequest()
        
        do {
            let entities = try viewContext.fetch(fetchRequest)
            return entities.map { $0.toConversation() }
        } catch {
            print("❌ Failed to fetch conversations: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Fetch specific conversation
    /// - Parameter conversationId: Conversation ID
    /// - Returns: Conversation if found
    func fetchConversation(conversationId: String) -> Conversation? {
        let fetchRequest = ConversationEntity.fetchRequest(for: conversationId)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            return results.first?.toConversation()
        } catch {
            print("❌ Failed to fetch conversation: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Update conversation with last message
    /// - Parameters:
    ///   - conversationId: Conversation ID
    ///   - lastMessage: Last message
    func updateConversationLastMessage(conversationId: String, lastMessage: LastMessage) {
        let fetchRequest = ConversationEntity.fetchRequest(for: conversationId)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            
            if let entity = results.first {
                entity.lastMessageText = lastMessage.text
                entity.lastMessageTimestamp = lastMessage.timestamp
                entity.updatedAt = lastMessage.timestamp
                try viewContext.save()
                print("✅ Updated conversation last message: \(conversationId)")
            }
        } catch {
            print("❌ Failed to update conversation last message: \(error.localizedDescription)")
        }
    }
    
    /// Delete conversation from Core Data
    /// - Parameter conversationId: Conversation ID
    func deleteConversation(conversationId: String) {
        let fetchRequest = ConversationEntity.fetchRequest(for: conversationId)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            
            if let entity = results.first {
                viewContext.delete(entity)
                try viewContext.save()
                print("✅ Deleted conversation: \(conversationId)")
            }
        } catch {
            print("❌ Failed to delete conversation: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Search Operations
    
    /// Search messages by text
    /// - Parameter query: Search query
    /// - Returns: Array of matching messages
    func searchMessages(query: String) -> [Message] {
        let fetchRequest = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
        fetchRequest.predicate = NSPredicate(format: "text CONTAINS[cd] %@", query)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        fetchRequest.fetchLimit = 50
        
        do {
            let entities = try viewContext.fetch(fetchRequest)
            return entities.map { $0.toMessage() }
        } catch {
            print("❌ Failed to search messages: \(error.localizedDescription)")
            return []
        }
    }
}

