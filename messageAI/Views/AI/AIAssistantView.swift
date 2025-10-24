//
//  AIAssistantView.swift
//  messageAI
//
//  Created by MessageAI Team
//  Dedicated AI assistant chat interface
//

import SwiftUI

struct AIAssistantView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var aiViewModel = AIInsightsViewModel()
    
    var body: some View {
        NavigationStack {
            VStack {
                if aiViewModel.insights.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 60))
                            .foregroundStyle(.purple.opacity(0.3))
                            .padding()
                        
                        Text("ai assistant")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("use the ai features in your chats to get intelligent insights")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            // Section: Advanced AI Features
                            VStack(alignment: .leading, spacing: 4) {
                                Text("advanced features")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                                    .padding(.horizontal)
                                
                                VStack(spacing: 12) {
                                    NavigationLink(destination: UnifiedAIDashboardView(currentUserId: authViewModel.currentUser?.id ?? "")) {
                                        FeatureRow(
                                            icon: "chart.bar.fill",
                                            title: "unified ai dashboard",
                                            description: "see all ai insights in one place"
                                        )
                                    }
                                    
                                    NavigationLink(destination: BlockerDashboardView(currentUserId: authViewModel.currentUser?.id ?? "")) {
                                        FeatureRow(
                                            icon: "exclamationmark.triangle.fill",
                                            title: "team blockers",
                                            description: "see when team members are stuck or waiting"
                                        )
                                    }
                                }
                            }
                            
                            Divider()
                                .padding(.horizontal)
                            
                            // Section: Core AI Features
                            VStack(alignment: .leading, spacing: 4) {
                                Text("core features")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                
                                VStack(spacing: 12) {
                                    FeatureRow(
                                        icon: "sparkles",
                                        title: "response suggestions",
                                        description: "ai suggests replies automatically in chats"
                                    )
                                    
                                    FeatureRow(
                                        icon: "doc.text",
                                        title: "summarize",
                                        description: "get 3 bullet point summaries of long conversations"
                                    )
                                    
                                    FeatureRow(
                                        icon: "checklist",
                                        title: "action items",
                                        description: "extract tasks with owners and deadlines"
                                    )
                                    
                                    FeatureRow(
                                        icon: "flag.fill",
                                        title: "priority detection",
                                        description: "urgent messages are automatically flagged"
                                    )
                                    
                                    FeatureRow(
                                        icon: "checkmark.circle",
                                        title: "decision tracking",
                                        description: "team decisions are logged automatically"
                                    )
                                }
                            }
                        }
                        .padding()
                    }
                } else {
                    // Show all insights across conversations
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(aiViewModel.insights) { insight in
                                AIInsightCardView(insight: insight) {
                                    Task {
                                        await aiViewModel.dismissInsight(
                                            insightId: insight.id,
                                            conversationId: insight.conversationId,
                                            currentUserId: authViewModel.currentUser?.id ?? ""
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.top)
                    }
                }
            }
            .navigationTitle("ai assistant")
        }
    }
}

/// Feature row for AI capabilities
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.purple)
                .font(.title3)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    AIAssistantView()
        .environmentObject(AuthViewModel())
}

