//
//  PersistenceController.swift
//  messageAI
//
//  Created by MessageAI Team
//  Core Data persistence controller
//

import Foundation
import CoreData

/// Singleton managing Core Data stack
class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    /// View context for main thread operations
    var viewContext: NSManagedObjectContext {
        return container.viewContext
    }
    
    /// Background context for heavy operations
    func newBackgroundContext() -> NSManagedObjectContext {
        return container.newBackgroundContext()
    }
    
    /// Initialize Core Data stack
    private init() {
        container = NSPersistentContainer(name: "MessageAI")
        
        // Configure persistent store description
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve persistent store description")
        }
        
        // Enable persistent history tracking
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Load persistent stores
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Core Data failed to load: \(error), \(error.userInfo)")
            }
            
            print("✅ Core Data store loaded: \(storeDescription.url?.lastPathComponent ?? "unknown")")
        }
        
        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        print("✅ Core Data initialized successfully")
    }
    
    /// Save view context
    func save() {
        let context = viewContext
        
        guard context.hasChanges else {
            return
        }
        
        do {
            try context.save()
            print("✅ Core Data saved successfully")
        } catch {
            let nsError = error as NSError
            print("❌ Core Data save failed: \(nsError), \(nsError.userInfo)")
        }
    }
    
    /// Save background context
    func saveContext(_ context: NSManagedObjectContext) {
        guard context.hasChanges else {
            return
        }
        
        do {
            try context.save()
            print("✅ Background context saved successfully")
        } catch {
            let nsError = error as NSError
            print("❌ Background context save failed: \(nsError), \(nsError.userInfo)")
        }
    }
    
    /// Delete all data (for testing)
    func deleteAllData() {
        let entities = container.managedObjectModel.entities
        
        for entity in entities {
            if let entityName = entity.name {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                
                do {
                    try viewContext.execute(deleteRequest)
                    print("✅ Deleted all data from \(entityName)")
                } catch {
                    print("❌ Failed to delete \(entityName): \(error.localizedDescription)")
                }
            }
        }
        
        save()
    }
}

