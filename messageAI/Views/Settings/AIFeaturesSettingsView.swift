//
//  AIFeaturesSettingsView.swift
//  messageAI
//
//  Settings panel for managing AI features
//

import SwiftUI

/// Settings view for AI features with privacy controls
struct AIFeaturesSettingsView: View {
    // Advanced AI features (new)
    @AppStorage("responseSuggestionsEnabled") private var suggestionsEnabled = true
    @AppStorage("blockerDetectionEnabled") private var blockerDetectionEnabled = true
    @AppStorage("blockerNotificationsEnabled") private var blockerNotifications = true
    @AppStorage("sentimentAnalysisEnabled") private var sentimentEnabled = true
    @AppStorage("sentimentAlertsEnabled") private var sentimentAlerts = true
    
    var body: some View {
        Form {
            // ============================================
            // HEADER
            // ============================================
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundColor(.blue)
                        Text("ai features")
                            .font(.title2.bold())
                    }
                    
                    Text("manage your ai powered management assistant features")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)
            
            // ============================================
            // ADVANCED AI FEATURES (NEW)
            // ============================================
            
            Section {
                Text("advanced ai features")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            .listRowBackground(Color.clear)
            
            // Response Suggestions
            Section {
                Toggle("smart response suggestions", isOn: $suggestionsEnabled)
                
                Text("ai generates contextual response options for messages requiring your input. saves 30 to 45 minutes per day.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Label("response suggestions", systemImage: "sparkles")
            }
            
            // Blocker Detection
            Section {
                Toggle("detect team blockers", isOn: $blockerDetectionEnabled)
                
                if blockerDetectionEnabled {
                    Toggle("blocker notifications", isOn: $blockerNotifications)
                        .padding(.leading, 16)
                }
                
                Text("automatically identifies when team members are stuck or waiting. you find out immediately instead of in the next standup.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Label("blocker detection", systemImage: "exclamationmark.triangle")
            }
            
            // Sentiment Analysis
            Section {
                Toggle("track team sentiment", isOn: $sentimentEnabled)
                
                if sentimentEnabled {
                    Toggle("sentiment alerts", isOn: $sentimentAlerts)
                        .padding(.leading, 16)
                }
                
                Text("monitors team mood and morale to help you spot stress, burnout, or team dynamics issues early.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Privacy note
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text("privacy: sentiment analysis is for team support only, never for surveillance or performance reviews. team members can opt out anytime.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.top, 4)
            } header: {
                Label("sentiment analysis", systemImage: "heart.fill")
            }
            
            // ============================================
            // EXISTING AI FEATURES (ALWAYS ON)
            // ============================================
            
            Section {
                Text("core ai features")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .listRowBackground(Color.clear)
            
            Section {
                AIFeatureStatusRow(
                    icon: "doc.text.fill",
                    iconColor: .purple,
                    title: "thread summarization",
                    status: "always on"
                )
                
                AIFeatureStatusRow(
                    icon: "checklist",
                    iconColor: .green,
                    title: "action items extraction",
                    status: "always on"
                )
                
                AIFeatureStatusRow(
                    icon: "magnifyingglass",
                    iconColor: .orange,
                    title: "smart search (rag)",
                    status: "always on"
                )
                
                AIFeatureStatusRow(
                    icon: "flag.fill",
                    iconColor: .red,
                    title: "priority detection",
                    status: "always on"
                )
                
                AIFeatureStatusRow(
                    icon: "checkmark.circle.fill",
                    iconColor: .blue,
                    title: "decision tracking",
                    status: "always on"
                )
            } header: {
                Text("core features")
            }
            
            // ============================================
            // PRIVACY INFORMATION
            // ============================================
            
            Section {
                NavigationLink(destination: PrivacyInformationView()) {
                    Label("privacy and data usage", systemImage: "hand.raised.fill")
                }
                
                NavigationLink(destination: AboutAIFeaturesView()) {
                    Label("about ai features", systemImage: "info.circle.fill")
                }
            } header: {
                Text("information")
            }
        }
        .navigationTitle("ai features")
        .navigationBarTitleDisplayMode(.large)
    }
}

/// Simple feature row showing status
struct AIFeatureStatusRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let status: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
            
            Spacer()
            
            Text(status)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

/// Privacy information view
struct PrivacyInformationView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("how we use your data")
                    .font(.title2.bold())
                
                privacySection(
                    title: "response suggestions",
                    icon: "sparkles",
                    color: .blue,
                    text: "analyzes your recent messages to learn your communication style. suggests responses based on conversation context. all ai processing happens in secure cloud functions. suggestions are cached for 5 minutes then deleted."
                )
                
                privacySection(
                    title: "blocker detection",
                    icon: "exclamationmark.triangle",
                    color: .orange,
                    text: "scans messages in conversations you're part of to detect when team members are stuck. only analyzes messages you have access to. detection data stored for resolution tracking, deleted after 30 days when resolved."
                )
                
                privacySection(
                    title: "sentiment analysis",
                    icon: "heart.fill",
                    color: .red,
                    text: "analyzes emotional tone of messages to help you support your team. sentiment scores are aggregated per person and per team. individual message sentiment data stored permanently for trend analysis. this is for team health support only, never for performance reviews or punitive purposes."
                )
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("your control")
                        .font(.headline)
                    
                    Text("• you can disable any feature anytime\n• disabling stops all processing immediately\n• you can delete your data by contacting support\n• team members can opt out individually")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("our commitment")
                        .font(.headline)
                    
                    Text("• we never sell your data\n• ai processing is encrypted and secure\n• only you and your team can see sentiment data\n• data used only for features you enable\n• transparent about what we analyze")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func privacySection(title: String, icon: String, color: Color, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
            }
            
            Text(text)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

/// About AI features view
struct AboutAIFeaturesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("messageai uses cutting edge ai to help busy managers lead remote teams more effectively")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                featureDetail(
                    title: "smart response suggestions",
                    icon: "sparkles",
                    color: .blue,
                    description: "saves 30 to 45 minutes per day by providing ai generated response options. matches your communication style and considers full conversation context."
                )
                
                featureDetail(
                    title: "proactive blocker detection",
                    icon: "exclamationmark.triangle",
                    color: .orange,
                    description: "prevents productivity loss by catching team blockers early. average blocker resolution time drops from days to hours."
                )
                
                featureDetail(
                    title: "team sentiment analysis",
                    icon: "heart.fill",
                    color: .red,
                    description: "spots morale issues 2 to 3 days earlier than you would normally notice. helps prevent burnout and support team mental health."
                )
                
                Divider()
                
                Text("powered by openai gpt 4o and built with privacy first design")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .navigationTitle("about")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func featureDetail(title: String, icon: String, color: Color, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AIFeaturesSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AIFeaturesSettingsView()
        }
    }
}
#endif

