//
//  SentimentDashboardViewModel.swift
//  messageAI
//
//  Advanced AI Feature: Team Sentiment Analysis
//  ViewModel managing sentiment dashboard data
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseFunctions

/// ViewModel managing sentiment dashboard
@MainActor
class SentimentDashboardViewModel: ObservableObject {
    @Published var teamSentiment: Double = 0.0  // -1.0 to 1.0
    @Published var sentimentTrend: [Date: Double] = [:]
    @Published var memberSentiments: [SentimentData] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private let functions = Functions.functions()

    /// Team sentiment score on 0-100 scale
    var displayScore: Int {
        return Int((teamSentiment + 1.0) * 50)
    }
    
    /// Team sentiment category
    var sentimentCategory: String {
        switch teamSentiment {
        case 0.5...1.0: return "very positive"
        case 0.2..<0.5: return "positive"
        case -0.2..<0.2: return "neutral"
        case -0.5..<(-0.2): return "negative"
        default: return "very negative"
        }
    }
    
    /// Team sentiment color
    var sentimentColor: Color {
        switch teamSentiment {
        case 0.5...1.0: return .green
        case 0.2..<0.5: return Color.green.opacity(0.6)
        case -0.2..<0.2: return .gray
        case -0.5..<(-0.2): return .orange
        default: return .red
        }
    }
    
    /// Trigger manual sentiment aggregation for a conversation
    /// - Parameter conversationId: Conversation ID (group chat)
    private func triggerManualAggregation(for conversationId: String) async throws {
        print("🔧 [SENTIMENT] triggering manual aggregation for conversation: \(conversationId)")

        do {
            let result = try await functions.httpsCallable("manualAggregateSentiment").call([
                "conversationId": conversationId
            ])

            if let data = result.data as? [String: Any] {
                print("✅ [SENTIMENT] manual aggregation succeeded!")
                print("   📊 Team sentiment: \(data["teamSentiment"] ?? "N/A")")
                print("   👥 Member count: \(data["memberCount"] ?? 0)")
                print("   📄 Document path: \(data["documentPath"] ?? "N/A")")
                if let memberSentiments = data["memberSentiments"] as? [String: Double] {
                    print("   👤 Member sentiments: \(memberSentiments)")
                }
            }
        } catch {
            print("❌ [SENTIMENT] manual aggregation failed: \(error)")
            print("⚠️ [SENTIMENT] continuing to load existing data (if any)...")
            // Don't throw - continue to try loading existing data
        }
    }

    /// Load team sentiment for conversation
    /// - Parameter conversationId: Conversation ID (group chat)
    func loadTeamSentiment(for conversationId: String) async {
        print("😊 [SENTIMENT] loading team sentiment for conversation: \(conversationId)")
        isLoading = true
        errorMessage = nil

        // ============================================
        // 0. TRIGGER MANUAL AGGREGATION FIRST
        // ============================================
        print("🔧 [SENTIMENT] step 1: triggering manual aggregation...")
        do {
            try await triggerManualAggregation(for: conversationId)
        } catch {
            print("⚠️ [SENTIMENT] aggregation trigger failed, continuing anyway...")
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFormatter.string(from: Date())

        print("📅 [SENTIMENT] step 2: looking for aggregate with date: \(todayStr)")

        do {
            // ============================================
            // 1. FETCH TEAM AGGREGATE FOR TODAY
            // ============================================
            let teamAggregateRef = db
                .collection("sentimentTracking")
                .document("teamDaily")
                .collection("aggregates")
                .document("\(todayStr)_\(conversationId)")

            print("🔍 [SENTIMENT] fetching document at path: sentimentTracking/teamDaily/aggregates/\(todayStr)_\(conversationId)")

            let teamDoc = try await teamAggregateRef.getDocument()

            print("📄 [SENTIMENT] document exists: \(teamDoc.exists)")

            if let teamData = teamDoc.data() {
                print("📊 [SENTIMENT] raw team data: \(teamData)")

                self.teamSentiment = teamData["averageSentiment"] as? Double ?? 0.0

                print("✅ [SENTIMENT] team sentiment set to: \(self.teamSentiment)")
                print("📈 [SENTIMENT] display score will be: \(self.displayScore)")
                print("🏷️ [SENTIMENT] category will be: \(self.sentimentCategory)")

                // ============================================
                // 2. FETCH TREND DATA (past 7 days)
                // ============================================
                await loadSentimentTrend(for: conversationId, dateFormatter: dateFormatter)

                // ============================================
                // 3. FETCH INDIVIDUAL MEMBER SENTIMENTS
                // ============================================
                if let memberSentiments = teamData["memberSentiments"] as? [String: Double] {
                    print("👥 [SENTIMENT] found member sentiments: \(memberSentiments)")
                    await loadMemberDetails(
                        memberSentiments: memberSentiments,
                        todayStr: todayStr,
                        dateFormatter: dateFormatter
                    )
                } else {
                    print("⚠️ [SENTIMENT] no memberSentiments field in team data")
                }
            } else {
                print("⚠️ [SENTIMENT] document exists but has no data - this should never happen")
                print("⚠️ [SENTIMENT] no sentiment aggregate found for today (\(todayStr))")
                print("💡 [SENTIMENT] the manualAggregateSentiment function needs to be called to populate this data")
                self.teamSentiment = 0.0
            }

            isLoading = false

        } catch {
            print("❌ [SENTIMENT] failed to load team sentiment: \(error.localizedDescription)")
            print("❌ [SENTIMENT] error details: \(error)")
            errorMessage = "couldn't load sentiment data"
            isLoading = false
        }
    }
    
    /// Load sentiment trend for past 7 days
    private func loadSentimentTrend(for conversationId: String, dateFormatter: DateFormatter) async {
        print("📈 [SENTIMENT] loading trend data for past 7 days...")
        var trendData: [Date: Double] = [:]

        // Fetch past 7 days
        for daysAgo in 0..<7 {
            guard let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) else {
                continue
            }

            let dateStr = dateFormatter.string(from: date)

            let docRef = db
                .collection("sentimentTracking")
                .document("teamDaily")
                .collection("aggregates")
                .document("\(dateStr)_\(conversationId)")

            do {
                let doc = try await docRef.getDocument()
                if let sentiment = doc.data()?["averageSentiment"] as? Double {
                    trendData[date] = sentiment
                    print("📈 [SENTIMENT] trend for \(dateStr): \(sentiment)")
                } else {
                    print("⚠️ [SENTIMENT] no sentiment data for \(dateStr) - document \(doc.exists ? "exists but empty" : "does not exist")")
                }
            } catch {
                print("❌ [SENTIMENT] error fetching trend for \(dateStr): \(error)")
            }
        }

        print("📊 [SENTIMENT] total trend points collected: \(trendData.count)")
        self.sentimentTrend = trendData
    }
    
    /// Load individual member sentiment details
    private func loadMemberDetails(
        memberSentiments: [String: Double],
        todayStr: String,
        dateFormatter: DateFormatter
    ) async {
        print("👥 [SENTIMENT] loading details for \(memberSentiments.count) members...")
        var sentimentDataArray: [SentimentData] = []

        for (userId, sentiment) in memberSentiments {
            // Fetch user info
            do {
                let userDoc = try await db.collection("users").document(userId).getDocument()
                let userName = userDoc.data()?["displayName"] as? String ?? "unknown"

                print("👤 [SENTIMENT] loading details for user: \(userName) (\(userId))")

                // Fetch detailed aggregate
                let aggregateDoc = try await db
                    .collection("sentimentTracking")
                    .document("userDaily")
                    .collection("aggregates")
                    .document("\(todayStr)_\(userId)")
                    .getDocument()

                if aggregateDoc.exists {
                    print("📄 [SENTIMENT] user aggregate data: \(aggregateDoc.data() ?? [:])")
                } else {
                    print("⚠️ [SENTIMENT] no user aggregate found for \(userName)")
                }

                let messageCount = aggregateDoc.data()?["messageCount"] as? Int ?? 0
                let emotionsDetected = aggregateDoc.data()?["emotionsDetected"] as? [String: Int] ?? [:]
                let trendStr = aggregateDoc.data()?["trend"] as? String ?? "stable"
                let trend = SentimentTrend(rawValue: trendStr) ?? .stable

                let sentimentData = SentimentData(
                    userId: userId,
                    userName: userName,
                    averageSentiment: sentiment,
                    trend: trend,
                    messageCount: messageCount,
                    emotionsDetected: emotionsDetected,
                    lastAnalyzed: Date()
                )

                sentimentDataArray.append(sentimentData)
                print("✅ [SENTIMENT] \(userName): \(sentiment) (\(messageCount) messages, \(emotionsDetected.count) emotions)")

            } catch {
                print("❌ [SENTIMENT] failed to load details for user \(userId): \(error.localizedDescription)")
            }
        }

        // Sort by concerning sentiment first (negative to positive)
        self.memberSentiments = sentimentDataArray.sorted { $0.averageSentiment < $1.averageSentiment }
        print("✅ [SENTIMENT] loaded \(self.memberSentiments.count) member sentiment records")
    }
}

