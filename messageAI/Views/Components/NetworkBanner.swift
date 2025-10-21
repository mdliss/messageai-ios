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
    
    var body: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.subheadline)
                
                Text("you're offline. messages will send when connected")
                    .font(.subheadline)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.orange)
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

