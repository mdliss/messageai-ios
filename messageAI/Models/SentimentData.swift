//
//  SentimentData.swift
//  messageAI
//
//  Advanced AI Feature: Team Sentiment Analysis
//  Models for sentiment tracking and aggregates
//

import Foundation
import SwiftUI
import FirebaseFirestore

/// Sentiment trend indicator
enum SentimentTrend: String, Codable {
    case improving
    case stable
    case declining
    
    var icon: String {
        switch self {
        case .improving: return "arrow.up.circle.fill"
        case .stable: return "arrow.right.circle.fill"
        case .declining: return "arrow.down.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .improving: return .green
        case .stable: return .gray
        case .declining: return .red
        }
    }
    
    var displayName: String {
        return rawValue
    }
}

/// Individual team member sentiment data
struct SentimentData: Identifiable, Codable {
    let id: String
    let userId: String
    let userName: String
    let averageSentiment: Double  // -1.0 to 1.0
    let trend: SentimentTrend
    let messageCount: Int
    let emotionsDetected: [String: Int]
    let lastAnalyzed: Date
    
    /// Sentiment category based on score
    var sentimentCategory: String {
        switch averageSentiment {
        case 0.5...1.0: return "very positive"
        case 0.2..<0.5: return "positive"
        case -0.2..<0.2: return "neutral"
        case -0.5..<(-0.2): return "negative"
        default: return "very negative"
        }
    }
    
    /// Sentiment color based on score
    var sentimentColor: Color {
        switch averageSentiment {
        case 0.5...1.0: return .green
        case 0.2..<0.5: return Color.green.opacity(0.6)
        case -0.2..<0.2: return .gray
        case -0.5..<(-0.2): return .orange
        default: return .red
        }
    }
    
    /// Sentiment score on 0-100 scale for display
    var displayScore: Int {
        return Int((averageSentiment + 1.0) * 50)
    }
    
    /// Top emotions (sorted by count)
    var topEmotions: [(String, Int)] {
        return emotionsDetected
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { ($0.key, $0.value) }
    }
    
    /// Initialize sentiment data
    init(id: String = UUID().uuidString,
         userId: String,
         userName: String,
         averageSentiment: Double,
         trend: SentimentTrend,
         messageCount: Int,
         emotionsDetected: [String: Int],
         lastAnalyzed: Date) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.averageSentiment = averageSentiment
        self.trend = trend
        self.messageCount = messageCount
        self.emotionsDetected = emotionsDetected
        self.lastAnalyzed = lastAnalyzed
    }
    
    /// Initialize from Firestore data
    init?(from data: [String: Any], userId: String, userName: String) {
        guard let averageSentiment = data["averageSentiment"] as? Double,
              let messageCount = data["messageCount"] as? Int,
              let trendStr = data["trend"] as? String,
              let trend = SentimentTrend(rawValue: trendStr) else {
            return nil
        }
        
        self.id = userId
        self.userId = userId
        self.userName = userName
        self.averageSentiment = averageSentiment
        self.trend = trend
        self.messageCount = messageCount
        self.emotionsDetected = data["emotionsDetected"] as? [String: Int] ?? [:]
        
        if let calculatedAtTimestamp = data["calculatedAt"] as? Timestamp {
            self.lastAnalyzed = calculatedAtTimestamp.dateValue()
        } else {
            self.lastAnalyzed = Date()
        }
    }
}

/// Message sentiment analysis
struct MessageSentimentAnalysis: Codable {
    let score: Double  // -1.0 to 1.0
    let emotions: [String]
    let confidence: Double
    let analyzedAt: Date
    let reasoning: String
    
    /// Initialize from Firestore data
    init?(from data: [String: Any]) {
        guard let score = data["score"] as? Double,
              let emotions = data["emotions"] as? [String],
              let confidence = data["confidence"] as? Double else {
            return nil
        }
        
        self.score = score
        self.emotions = emotions
        self.confidence = confidence
        self.reasoning = data["reasoning"] as? String ?? ""
        
        if let analyzedAtTimestamp = data["analyzedAt"] as? Timestamp {
            self.analyzedAt = analyzedAtTimestamp.dateValue()
        } else {
            self.analyzedAt = Date()
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension SentimentData {
    /// Sample positive sentiment
    static let samplePositive = SentimentData(
        userId: "user123",
        userName: "Alice Johnson",
        averageSentiment: 0.65,
        trend: .improving,
        messageCount: 15,
        emotionsDetected: ["excited": 5, "happy": 4, "enthusiastic": 3],
        lastAnalyzed: Date()
    )
    
    /// Sample negative sentiment
    static let sampleNegative = SentimentData(
        userId: "user456",
        userName: "Bob Wilson",
        averageSentiment: -0.42,
        trend: .declining,
        messageCount: 12,
        emotionsDetected: ["frustrated": 6, "stressed": 4, "confused": 2],
        lastAnalyzed: Date()
    )
    
    /// Sample neutral sentiment
    static let sampleNeutral = SentimentData(
        userId: "user789",
        userName: "Carol Smith",
        averageSentiment: 0.05,
        trend: .stable,
        messageCount: 20,
        emotionsDetected: [:],
        lastAnalyzed: Date()
    )
    
    static let samples = [sampleNegative, sampleNeutral, samplePositive]
}
#endif

