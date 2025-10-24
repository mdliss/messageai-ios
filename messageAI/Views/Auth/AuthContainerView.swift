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
                    .environmentObject(authViewModel)
            } else {
                // User is not logged in - show login
                LoginView()
            }
        }
    }
}

/// Main tab view for authenticated users
struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
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
            
            // AI Dashboard tab - FIXED: Direct navigation to unified dashboard
            UnifiedAIDashboardView(currentUserId: authViewModel.currentUser?.id ?? "")
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

// DecisionsView moved to separate file

// AIAssistantView moved to separate file

#Preview {
    AuthContainerView()
        .environmentObject(AuthViewModel())
}

