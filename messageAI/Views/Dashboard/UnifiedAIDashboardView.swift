//
//  UnifiedAIDashboardView.swift
//  messageAI
//
//  Unified dashboard showing all AI insights and features
//  Combines: Response Suggestions, Blockers, Sentiment, Priority Messages, Action Items
//

import SwiftUI

/// Unified AI dashboard showing all AI features
struct UnifiedAIDashboardView: View {
    let currentUserId: String
    
    @State private var blockerCount: Int = 0
    @State private var suggestionsAvailable: Int = 0
    @State private var teamSentimentScore: Double = 0.0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ai insights")
                            .font(.largeTitle.bold())
                        Text("your ai powered team management assistant")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // ============================================
                    // NEW ADVANCED FEATURES
                    // ============================================
                    
                    VStack(spacing: 16) {
                        // Response suggestions (info only, automatic in chats)
                        DashboardCardView(
                            icon: "sparkles",
                            iconColor: .blue,
                            title: "response suggestions",
                            subtitle: "\(suggestionsAvailable) available",
                            description: "ai suggests replies automatically in your chats"
                        )
                        
                        // Active blockers - NavigationLink
                        NavigationLink(destination: BlockerDashboardView(currentUserId: currentUserId)) {
                            DashboardCardView(
                                icon: "exclamationmark.triangle.fill",
                                iconColor: blockerCount > 0 ? .red : .gray,
                                title: "team blockers",
                                subtitle: "\(blockerCount) active",
                                description: "team members who are stuck or waiting"
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Team sentiment (info only - need conversation selection)
                        DashboardCardView(
                            icon: "heart.fill",
                            iconColor: sentimentColor,
                            title: "team sentiment",
                            subtitle: sentimentCategory,
                            description: "view sentiment in group chat menus"
                        )
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding()
                    
                    // ============================================
                    // EXISTING AI FEATURES
                    // ============================================
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("existing ai features")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            // Priority messages (info only, no chevron)
                            DashboardCardView(
                                icon: "flag.fill",
                                iconColor: .red,
                                title: "priority messages",
                                subtitle: "urgent and important",
                                description: "never miss critical communications",
                                showChevron: false
                            )
                            
                            // Action items (info only, no chevron)
                            DashboardCardView(
                                icon: "checklist",
                                iconColor: .green,
                                title: "action items",
                                subtitle: "ai extracted tasks",
                                description: "never lose track of commitments",
                                showChevron: false
                            )
                            
                            // Thread summarization (info only, no chevron)
                            DashboardCardView(
                                icon: "doc.text.fill",
                                iconColor: .purple,
                                title: "thread summaries",
                                subtitle: "ai generated",
                                description: "get up to speed quickly",
                                showChevron: false
                            )
                            
                            // Smart search (info only, no chevron)
                            DashboardCardView(
                                icon: "magnifyingglass",
                                iconColor: .orange,
                                title: "smart search",
                                subtitle: "rag powered",
                                description: "find anything by meaning, not just keywords",
                                showChevron: false
                            )
                            
                            // Decision tracking (info only, no chevron)
                            DashboardCardView(
                                icon: "checkmark.circle.fill",
                                iconColor: .blue,
                                title: "decision tracking",
                                subtitle: "auto detected",
                                description: "keep track of team decisions",
                                showChevron: false
                            )
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("ai dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: AIFeaturesSettingsView()) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .task {
            // Load counts and stats
            await loadDashboardData()
        }
    }
    
    // MARK: - Computed Properties
    
    private var sentimentCategory: String {
        switch teamSentimentScore {
        case 0.5...1.0: return "very positive"
        case 0.2..<0.5: return "positive"
        case -0.2..<0.2: return "neutral"
        case -0.5..<(-0.2): return "negative"
        default: return "very negative"
        }
    }
    
    private var sentimentColor: Color {
        switch teamSentimentScore {
        case 0.5...1.0: return .green
        case 0.2..<0.5: return Color.green.opacity(0.6)
        case -0.2..<0.2: return .gray
        case -0.5..<(-0.2): return .orange
        default: return .red
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadDashboardData() async {
        print("📊 loading unified dashboard data...")
        
        // TODO: Load actual counts from Firestore
        // For now, using stub data
        blockerCount = 0
        suggestionsAvailable = 0
        teamSentimentScore = 0.0
    }
}

/// Reusable dashboard card component (non-interactive version)
struct DashboardCardView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let description: String
    var showChevron: Bool = true  // NEW: Optional chevron for non-interactive items
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.1))
                .clipShape(Circle())
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Chevron (optional)
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#if DEBUG
struct UnifiedAIDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        UnifiedAIDashboardView(currentUserId: "testUser123")
    }
}
#endif

