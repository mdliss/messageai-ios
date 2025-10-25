//
//  UnifiedAIDashboardView.swift
//  messageAI
//
//  Unified dashboard showing all AI insights and features
//  Combines: Response Suggestions, Blockers, Sentiment, Priority Messages, Action Items
//

import SwiftUI
import FirebaseFirestore

/// Unified AI dashboard showing all AI features
struct UnifiedAIDashboardView: View {
    let currentUserId: String

    @State private var blockerCount: Int = 0
    @State private var suggestionsAvailable: Int = 0
    @State private var teamSentimentScore: Double = 0.0
    @State private var groupConversationId: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
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
                        
                        // Team sentiment - NavigationLink to sentiment dashboard
                        if let conversationId = groupConversationId {
                            NavigationLink(destination: SentimentDashboardView(conversationId: conversationId)) {
                                DashboardCardView(
                                    icon: "heart.fill",
                                    iconColor: sentimentColor,
                                    title: "team sentiment",
                                    subtitle: sentimentCategory,
                                    description: "tap to view team sentiment analysis"
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            DashboardCardView(
                                icon: "heart.fill",
                                iconColor: .gray,
                                title: "team sentiment",
                                subtitle: "no group chats",
                                description: "join or create a group chat to see sentiment",
                                showChevron: false
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding()
                    
                    // ============================================
                    // OTHER AI FEATURES
                    // ============================================

                    VStack(alignment: .leading, spacing: 12) {
                        Text("other features")
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
        print("📊 [DASHBOARD] loading unified dashboard data...")

        // Load the most recent group conversation for sentiment analysis
        do {
            let db = Firestore.firestore()

            // Find first group conversation where user is a participant
            print("🔍 [DASHBOARD] searching for group conversations...")
            let conversationsSnapshot = try await db.collection("conversations")
                .whereField("participantIds", arrayContains: currentUserId)
                .whereField("type", isEqualTo: "group")
                .getDocuments()

            if let firstConversation = conversationsSnapshot.documents.first {
                groupConversationId = firstConversation.documentID
                print("✅ [DASHBOARD] found group conversation: \(firstConversation.documentID)")

                // Load today's sentiment aggregate
                await loadTodaysSentiment(conversationId: firstConversation.documentID)
            } else {
                print("⚠️ [DASHBOARD] no group conversations found for user")
                groupConversationId = nil
            }
        } catch {
            print("❌ [DASHBOARD] error loading group conversation: \(error)")
            groupConversationId = nil
        }

        // TODO: Load actual counts from Firestore
        blockerCount = 0
        suggestionsAvailable = 0
    }

    private func loadTodaysSentiment(conversationId: String) async {
        print("📊 [DASHBOARD] loading today's sentiment for preview...")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFormatter.string(from: Date())

        do {
            let db = Firestore.firestore()
            let doc = try await db
                .collection("sentimentTracking")
                .document("teamDaily")
                .collection("aggregates")
                .document("\(todayStr)_\(conversationId)")
                .getDocument()

            if let sentiment = doc.data()?["averageSentiment"] as? Double {
                teamSentimentScore = sentiment
                print("✅ [DASHBOARD] loaded sentiment preview: \(sentiment)")
            } else {
                print("⚠️ [DASHBOARD] no sentiment data for today yet")
                teamSentimentScore = 0.0
            }
        } catch {
            print("❌ [DASHBOARD] error loading sentiment preview: \(error)")
            teamSentimentScore = 0.0
        }
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

