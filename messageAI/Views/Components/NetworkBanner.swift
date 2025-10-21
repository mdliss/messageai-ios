//
//  NetworkBanner.swift
//  messageAI
//
//  Created by MessageAI Team
//  Banner showing network connectivity status
//

import SwiftUI

struct NetworkBanner: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    @ObservedObject var syncService = SyncService.shared
    
    var body: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.subheadline)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("you're offline")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if syncService.pendingCount > 0 {
                        Text("\(syncService.pendingCount) message\(syncService.pendingCount == 1 ? "" : "s") waiting to send")
                            .font(.caption)
                            .opacity(0.9)
                    } else {
                        Text("messages will queue and send when connected")
                            .font(.caption)
                            .opacity(0.9)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.orange)
            .foregroundStyle(.white)
            .transition(.move(edge: .top).combined(with: .opacity))
        } else if syncService.isSyncing {
            HStack(spacing: 8) {
                ProgressView()
                    .tint(.white)
                
                Text("syncing \(syncService.pendingCount) message\(syncService.pendingCount == 1 ? "" : "s")...")
                    .font(.subheadline)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.blue)
            .foregroundStyle(.white)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

#Preview {
    VStack {
        NetworkBanner()
        Spacer()
    }
}

