//
//  SyncService.swift
//  messageAI
//
//  Created by MessageAI Team
//  Service for syncing offline messages to Firestore
//

import Foundation
import Combine
import SwiftUI

/// Service managing offline message sync
@MainActor
class SyncService: ObservableObject {
    static let shared = SyncService()
    
    @Published var isSyncing = false
    @Published var pendingCount = 0
    
    private let firestoreService = FirestoreService.shared
    private let coreDataService = CoreDataService.shared
    private let networkMonitor = NetworkMonitor.shared
    
    private var cancellables = Set<AnyCancellable>()
    private var syncTask: Task<Void, Never>?
    
    private init() {
        setupNetworkListener()
        updatePendingCount()
    }
    
    // MARK: - Network Listener
    
    /// Set up listener for network reconnection
    private func setupNetworkListener() {
        NotificationCenter.default.publisher(for: .networkConnected)
            .sink { [weak self] notification in
                let receivedAt = Date()
                print("📡 Network connected notification received at \(receivedAt)")
                
                Task {
                    let syncStartedAt = Date()
                    let delay = syncStartedAt.timeIntervalSince(receivedAt)
                    print("🔄 Starting sync at \(syncStartedAt) (delay: \(String(format: "%.3f", delay))s)")
                    
                    await self?.processPendingMessages()
                    
                    let syncEndedAt = Date()
                    let duration = syncEndedAt.timeIntervalSince(syncStartedAt)
                    print("✅ Sync completed at \(syncEndedAt) (duration: \(String(format: "%.3f", duration))s)")
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Process Pending Messages
    
    /// Process all pending messages from Core Data
    func processPendingMessages() async {
        guard networkMonitor.isConnected else {
            print("ℹ️ Cannot sync: Network offline")
            return
        }
        
        guard !isSyncing else {
            print("ℹ️ Sync already in progress")
            return
        }
        
        isSyncing = true
        
        let unsyncedMessages = coreDataService.fetchUnsyncedMessages()
        
        guard !unsyncedMessages.isEmpty else {
            print("ℹ️ No pending messages to sync")
            isSyncing = false
            pendingCount = 0
            return
        }
        
        print("🔄 Syncing \(unsyncedMessages.count) pending messages...")
        
        var successCount = 0
        var failedCount = 0
        
        for message in unsyncedMessages {
            do {
                let serverId = try await uploadMessageWithRetry(message)
                
                // Update Core Data with server ID
                if let localId = message.localId {
                    coreDataService.updateMessageSync(localId: localId, serverId: serverId)
                }
                
                successCount += 1
                print("✅ Synced message: \(serverId)")
            } catch {
                failedCount += 1
                print("❌ Failed to sync message \(message.id): \(error.localizedDescription)")
                
                // Mark as failed in Core Data
                coreDataService.updateMessageStatus(messageId: message.id, status: .failed)
            }
        }
        
        print("✅ Sync complete: \(successCount) succeeded, \(failedCount) failed")
        
        isSyncing = false
        updatePendingCount()
    }
    
    // MARK: - Upload with Retry
    
    /// Upload message with retry logic
    /// - Parameter message: Message to upload
    /// - Returns: Server-assigned message ID
    private func uploadMessageWithRetry(_ message: Message, attempt: Int = 1) async throws -> String {
        let maxAttempts = 3
        
        do {
            let serverId = try await firestoreService.sendMessage(message, to: message.conversationId)
            return serverId
        } catch {
            if attempt < maxAttempts {
                // Exponential backoff: 1s, 2s, 4s
                let delay = TimeInterval(pow(2.0, Double(attempt - 1)))
                print("⚠️ Upload failed (attempt \(attempt)/\(maxAttempts)), retrying in \(delay)s...")
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await uploadMessageWithRetry(message, attempt: attempt + 1)
            } else {
                throw error
            }
        }
    }
    
    // MARK: - Pending Count
    
    /// Update pending message count
    func updatePendingCount() {
        let unsynced = coreDataService.fetchUnsyncedMessages()
        pendingCount = unsynced.count
        print("ℹ️ Pending messages: \(pendingCount)")
    }
    
    // MARK: - Manual Sync
    
    /// Manually trigger sync
    func syncNow() {
        Task {
            await processPendingMessages()
        }
    }
}

