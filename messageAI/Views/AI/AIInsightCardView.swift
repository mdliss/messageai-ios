//
//  AIInsightCardView.swift
//  messageAI
//
//  Created by MessageAI Team
//  Card view for displaying AI insights
//

import SwiftUI

struct AIInsightCardView: View {
    let insight: AIInsight
    let onDismiss: () -> Void
    let onAcceptSuggestion: (() -> Void)?
    
    // Initialize with optional accept callback
    init(insight: AIInsight, onDismiss: @escaping () -> Void, onAcceptSuggestion: (() -> Void)? = nil) {
        self.insight = insight
        self.onDismiss = onDismiss
        self.onAcceptSuggestion = onAcceptSuggestion
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: insight.icon)
                    .foregroundStyle(iconColor)
                    .font(.title3)
                
                Text(insight.title)
                    .font(.headline)
                    .foregroundStyle(iconColor)
                
                Spacer()
                
                // Dismiss button (always visible)
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
            }
            
            // Content
            Text(insight.content)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            
            // Interactive buttons for scheduling suggestions
            if insight.type == .suggestion, 
               let metadata = insight.metadata,
               metadata.action == "scheduling_help",
               let onAccept = onAcceptSuggestion {
                
                HStack(spacing: 12) {
                    // Accept button
                    Button {
                        onAccept()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("yes, help me")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .cornerRadius(8)
                    }
                    
                    // Decline button
                    Button {
                        onDismiss()
                    } label: {
                        Text("no thanks")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding(.top, 4)
            }
            
            // Metadata
            HStack {
                if let metadata = insight.metadata {
                    if let messageCount = metadata.messageCount {
                        Label("\(messageCount) messages", systemImage: "message")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let confidence = metadata.confidence {
                        Label("\(Int(confidence * 100))% confident", systemImage: "chart.bar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Text(insight.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    // MARK: - Styling
    
    private var iconColor: Color {
        switch insight.type {
        case .summary:
            return .blue
        case .actionItems:
            return .green
        case .decision:
            return .purple
        case .priority:
            return .red
        case .suggestion:
            return .orange
        }
    }
    
    private var backgroundColor: Color {
        switch insight.type {
        case .summary:
            return Color.blue.opacity(0.1)
        case .actionItems:
            return Color.green.opacity(0.1)
        case .decision:
            return Color.purple.opacity(0.1)
        case .priority:
            return Color.red.opacity(0.1)
        case .suggestion:
            return Color.orange.opacity(0.1)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        AIInsightCardView(
            insight: AIInsight(
                conversationId: "1",
                type: .summary,
                content: "• Team decided to use PostgreSQL\n• Alice will prototype dashboard by Friday\n• Deployment scheduled for Tuesday 2pm",
                metadata: InsightMetadata(bulletPoints: 3, messageCount: 50),
                triggeredBy: "user1"
            ),
            onDismiss: {}
        )
        
        AIInsightCardView(
            insight: AIInsight(
                conversationId: "1",
                type: .actionItems,
                content: "• Alice: Design mockups for settings page (by Friday)\n• Bob: Review PR #234\n• Carol: Schedule stakeholder meeting",
                metadata: InsightMetadata(messageCount: 30),
                triggeredBy: "user1"
            ),
            onDismiss: {}
        )
        
        AIInsightCardView(
            insight: AIInsight(
                conversationId: "1",
                type: .suggestion,
                content: "Would you like me to help find a time that works for everyone?",
                metadata: InsightMetadata(action: "scheduling_help", confidence: 0.85),
                triggeredBy: "system"
            ),
            onDismiss: {}
        )
    }
}

