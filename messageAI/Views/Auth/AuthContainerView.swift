//
//  AuthContainerView.swift
//  messageAI
//
//  Created by MessageAI Team
//  Container view that shows login or main app based on auth state
//

import SwiftUI

struct AuthContainerView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                // User is logged in - show main app
                MainTabView()
            } else {
                // User is not logged in - show login
                LoginView()
            }
        }
    }
}

/// Main tab view for authenticated users
struct MainTabView: View {
    var body: some View {
        TabView {
            // Conversations tab
            ConversationListView()
                .tabItem {
                    Label("chats", systemImage: "message.fill")
                }
            
            // Decisions tab (placeholder for PR #19)
            DecisionsView()
                .tabItem {
                    Label("decisions", systemImage: "list.clipboard")
                }
            
            // AI Assistant tab (placeholder for PR #20B)
            AIAssistantView()
                .tabItem {
                    Label("ai", systemImage: "sparkles")
                }
            
            // Profile tab
            ProfileView()
                .tabItem {
                    Label("profile", systemImage: "person.circle.fill")
                }
        }
    }
}

// MARK: - Placeholder Views

// ConversationListView moved to separate file

/// Temporary decisions view (will be replaced in PR #19)
struct DecisionsView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "list.clipboard")
                    .font(.system(size: 60))
                    .foregroundStyle(.purple.opacity(0.3))
                    .padding()
                
                Text("decisions")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("team decisions will be tracked here")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .navigationTitle("decisions")
        }
    }
}

/// Temporary AI assistant view (will be replaced in PR #20B)
struct AIAssistantView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundStyle(.purple.opacity(0.3))
                    .padding()
                
                Text("ai assistant")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("your ai assistant will help you here")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .navigationTitle("ai assistant")
        }
    }
}

#Preview {
    AuthContainerView()
        .environmentObject(AuthViewModel())
}

