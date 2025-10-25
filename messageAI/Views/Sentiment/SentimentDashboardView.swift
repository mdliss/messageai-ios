//
//  SentimentDashboardView.swift
//  messageAI
//
//  Advanced AI Feature: Team Sentiment Analysis
//  Main sentiment dashboard and related components
//

import SwiftUI
import Charts

/// Main sentiment dashboard showing team and individual sentiment
struct SentimentDashboardView: View {
    let conversationId: String
    
    @StateObject private var viewModel = SentimentDashboardViewModel()
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("loading sentiment data...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Team sentiment overview
                            TeamSentimentCard(viewModel: viewModel)
                            
                            Divider()
                                .padding(.horizontal)
                            
                            // Individual team members
                            VStack(alignment: .leading, spacing: 12) {
                                Text("team members")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(viewModel.memberSentiments) { member in
                                    MemberSentimentCard(sentiment: member)
                                        .padding(.horizontal)
                                }
                            }
                            
                            // Privacy note
                            Text("sentiment analysis is for team support only. use this data to check in with team members and improve team health, never for punitive purposes.")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.center)
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("team sentiment")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.loadTeamSentiment(for: conversationId)
            }
        }
        .task {
            await viewModel.loadTeamSentiment(for: conversationId)
        }
    }
}

/// Card showing overall team sentiment with trend graph
struct TeamSentimentCard: View {
    @ObservedObject var viewModel: SentimentDashboardViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("overall team sentiment")
                    .font(.headline)
                Spacer()
            }
            
            // Sentiment indicator
            HStack(spacing: 20) {
                // Circular score indicator
                ZStack {
                    Circle()
                        .fill(viewModel.sentimentColor.opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .stroke(viewModel.sentimentColor, lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    VStack(spacing: 2) {
                        Text("\(viewModel.displayScore)")
                            .font(.title.bold())
                            .foregroundColor(viewModel.sentimentColor)
                        
                        Text("/100")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Category and stats
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.sentimentCategory)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(viewModel.sentimentColor)
                    
                    Text("past 7 days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Quick stats
                    let positiveCount = viewModel.memberSentiments.filter { $0.averageSentiment > 0.2 }.count
                    let neutralCount = viewModel.memberSentiments.filter { $0.averageSentiment >= -0.2 && $0.averageSentiment <= 0.2 }.count
                    let negativeCount = viewModel.memberSentiments.filter { $0.averageSentiment < -0.2 }.count
                    
                    if !viewModel.memberSentiments.isEmpty {
                        HStack(spacing: 8) {
                            if positiveCount > 0 {
                                statBadge(count: positiveCount, label: "positive", color: .green)
                            }
                            if neutralCount > 0 {
                                statBadge(count: neutralCount, label: "neutral", color: .gray)
                            }
                            if negativeCount > 0 {
                                statBadge(count: negativeCount, label: "stressed", color: .orange)
                            }
                        }
                        .font(.caption2)
                    }
                }
                
                Spacer()
            }
            
            // Trend graph
            if !viewModel.sentimentTrend.isEmpty {
                SentimentTrendGraph(trendData: viewModel.sentimentTrend)
                    .frame(height: 120)
            }
        }
        .padding()
        .background(viewModel.sentimentColor.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(viewModel.sentimentColor.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    private func statBadge(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(count) \(label)")
                .foregroundColor(color)
        }
    }
}

/// Sentiment trend graph using Swift Charts
struct SentimentTrendGraph: View {
    let trendData: [Date: Double]
    
    var sortedData: [(Date, Double)] {
        return trendData.sorted { $0.key < $1.key }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("7 day trend")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            if sortedData.isEmpty {
                Text("not enough data for trend")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                Chart {
                    ForEach(sortedData, id: \.0) { date, sentiment in
                        LineMark(
                            x: .value("date", date),
                            y: .value("sentiment", (sentiment + 1.0) * 50)  // Convert to 0-100
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("date", date),
                            y: .value("sentiment", (sentiment + 1.0) * 50)
                        )
                        .foregroundStyle(.blue.opacity(0.1))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 100)
            }
        }
    }
}

/// Card showing individual member sentiment
struct MemberSentimentCard: View {
    let sentiment: SentimentData
    
    var body: some View {
        HStack(spacing: 12) {
            // Sentiment indicator
            ZStack {
                Circle()
                    .fill(sentiment.sentimentColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Circle()
                    .stroke(sentiment.sentimentColor, lineWidth: 3)
                    .frame(width: 50, height: 50)
                
                Text("\(sentiment.displayScore)")
                    .font(.caption.bold())
                    .foregroundColor(sentiment.sentimentColor)
            }
            
            // Member info
            VStack(alignment: .leading, spacing: 4) {
                Text(sentiment.userName)
                    .font(.headline)

                // Sentiment category
                Text(sentiment.sentimentCategory)
                    .font(.subheadline)
                    .foregroundColor(sentiment.sentimentColor)
                
                // Top emotions
                if !sentiment.topEmotions.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(sentiment.topEmotions, id: \.0) { emotion, count in
                            Text("\(emotion) (\(count))")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray5))
                                .cornerRadius(4)
                        }
                    }
                }
                
                // Message count
                Text("\(sentiment.messageCount) messages analyzed")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(sentiment.sentimentColor.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(sentiment.sentimentColor.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Previews

#if DEBUG
struct SentimentDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        SentimentDashboardView(conversationId: "testConvo123")
    }
}

struct TeamSentimentCard_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = SentimentDashboardViewModel()
        viewModel.teamSentiment = 0.42
        viewModel.memberSentiments = SentimentData.samples
        
        return TeamSentimentCard(viewModel: viewModel)
            .padding()
    }
}

struct MemberSentimentCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            MemberSentimentCard(sentiment: SentimentData.samplePositive)
            MemberSentimentCard(sentiment: SentimentData.sampleNeutral)
            MemberSentimentCard(sentiment: SentimentData.sampleNegative)
        }
        .padding()
    }
}
#endif

