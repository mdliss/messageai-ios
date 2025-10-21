//
//  NetworkMonitor.swift
//  messageAI
//
//  Created by MessageAI Team
//  Network reachability monitor using Network framework
//

import Foundation
import Network
import Combine

/// Network connectivity monitor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected = true
    @Published var connectionType: NWInterface.InterfaceType?
    
    // Debug mode for testing offline functionality
    @Published var debugOfflineMode = false
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }
    
    /// Toggle debug offline mode for testing
    func toggleDebugOfflineMode() {
        debugOfflineMode.toggle()
        isConnected = !debugOfflineMode
        
        if debugOfflineMode {
            print("🐛 DEBUG: Offline mode enabled")
            NotificationCenter.default.post(name: .networkDisconnected, object: nil)
        } else {
            print("🐛 DEBUG: Offline mode disabled")
            NotificationCenter.default.post(name: .networkConnected, object: nil)
        }
    }
    
    /// Start monitoring network connectivity
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                // Skip real network updates if in debug mode
                guard self?.debugOfflineMode == false else { return }
                
                let wasConnected = self?.isConnected ?? true
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
                
                // Log status changes
                if wasConnected != self?.isConnected {
                    if self?.isConnected == true {
                        print("✅ Network connected")
                        NotificationCenter.default.post(name: .networkConnected, object: nil)
                    } else {
                        print("❌ Network disconnected")
                        NotificationCenter.default.post(name: .networkDisconnected, object: nil)
                    }
                }
            }
        }
        
        monitor.start(queue: queue)
        print("✅ Network monitor started")
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        monitor.cancel()
        print("ℹ️ Network monitor stopped")
    }
    
    deinit {
        stopMonitoring()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let networkConnected = Notification.Name("networkConnected")
    static let networkDisconnected = Notification.Name("networkDisconnected")
}

