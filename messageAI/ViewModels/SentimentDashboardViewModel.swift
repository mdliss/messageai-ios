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

/// ViewModel managing sentiment dashboard
@MainActor
class SentimentDashboardViewModel: ObservableObject {
    @Published var teamSentiment: Double = 0.0  // -1.0 to 1.0
    @Published var sentimentTrend: [Date: Double] = [:]
    @Published var memberSentiments: [SentimentData] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
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
    
    /// Load team sentiment for conversation
    /// - Parameter conversationId: Conversation ID (group chat)
    func loadTeamSentiment(for conversationId: String) async {
        print("😊 loading team sentiment for conversation: \(conversationId)")
        isLoading = true
        errorMessage = nil
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFormatter.string(from: Date())
        
        do {
            // ============================================
            // 1. FETCH TEAM AGGREGATE FOR TODAY
            // ============================================
            let teamAggregateRef = db
                .collection("sentimentTracking")
                .document("teamDaily")
                .collection("aggregates")
                .document("\(todayStr)_\(conversationId)")
            
            let teamDoc = try await teamAggregateRef.getDocument()
            
            if let teamData = teamDoc.data() {
                self.teamSentiment = teamData["averageSentiment"] as? Double ?? 0.0
                
                print("📊 team sentiment: \(self.teamSentiment)")
                
                // ============================================
                // 2. FETCH TREND DATA (past 7 days)
                // ============================================
                await loadSentimentTrend(for: conversationId, dateFormatter: dateFormatter)
                
                // ============================================
                // 3. FETCH INDIVIDUAL MEMBER SENTIMENTS
                // ============================================
                if let memberSentiments = teamData["memberSentiments"] as? [String: Double] {
                    await loadMemberDetails(
                        memberSentiments: memberSentiments,
                        todayStr: todayStr,
                        dateFormatter: dateFormatter
                    )
                }
            } else {
                print("⚠️ no sentiment data found for today")
                self.teamSentiment = 0.0
            }
            
            isLoading = false
            
        } catch {
            print("❌ failed to load team sentiment: \(error.localizedDescription)")
            errorMessage = "couldn't load sentiment data"
            isLoading = false
        }
    }
    
    /// Load sentiment trend for past 7 days
    private func loadSentimentTrend(for conversationId: String, dateFormatter: DateFormatter) async {
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
                    print("📈 trend for \(dateStr): \(sentiment)")
                }
            } catch {
                print("⚠️ no data for \(dateStr)")
            }
        }
        
        self.sentimentTrend = trendData
    }
    
    /// Load individual member sentiment details
    private func loadMemberDetails(
        memberSentiments: [String: Double],
        todayStr: String,
        dateFormatter: DateFormatter
    ) async {
        var sentimentDataArray: [SentimentData] = []
        
        for (userId, sentiment) in memberSentiments {
            // Fetch user info
            do {
                let userDoc = try await db.collection("users").document(userId).getDocument()
                let userName = userDoc.data()?["displayName"] as? String ?? "unknown"
                
                // Fetch detailed aggregate
                let aggregateDoc = try await db
                    .collection("sentimentTracking")
                    .document("userDaily")
                    .collection("aggregates")
                    .document("\(todayStr)_\(userId)")
                    .getDocument()
                
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
                print("👤 \(userName): \(sentiment)")
                
            } catch {
                print("⚠️ failed to load details for user \(userId): \(error.localizedDescription)")
            }
        }
        
        // Sort by concerning sentiment first (negative to positive)
        self.memberSentiments = sentimentDataArray.sorted { $0.averageSentiment < $1.averageSentiment }
    }
}

