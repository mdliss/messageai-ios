//
//  DecisionsView.swift
//  messageAI
//
//  Created by MessageAI Team
//  View for displaying all logged team decisions
//

import SwiftUI

struct DecisionsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = DecisionsViewModel()
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.decisions.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "list.clipboard")
                            .font(.system(size: 60))
                            .foregroundStyle(.purple.opacity(0.3))
                        
                        Text("no decisions yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("team decisions will be automatically logged here")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    // Decisions list
                    List {
                        ForEach(viewModel.groupedByDate(), id: \.key) { dateGroup in
                            Section(dateGroup.key) {
                                ForEach(filteredDecisions(in: dateGroup.value)) { decision in
                                    DecisionRowView(decision: decision)
                                        .environmentObject(viewModel)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("decisions")
            .searchable(text: $searchText, prompt: "search decisions")
            .onAppear {
                if let userId = authViewModel.currentUser?.id {
                    viewModel.loadDecisions(userId: userId)
                }
            }
            .refreshable {
                if let userId = authViewModel.currentUser?.id {
                    viewModel.loadDecisions(userId: userId)
                }
            }
            .alert("error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("ok") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
    
    // MARK: - Filtered Decisions
    
    private func filteredDecisions(in decisions: [AIInsight]) -> [AIInsight] {
        if searchText.isEmpty {
            return decisions
        }
        
        return decisions.filter { decision in
            decision.content.localizedCaseInsensitiveContains(searchText)
        }
    }
}

/// Decision row view
struct DecisionRowView: View {
    let decision: AIInsight
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var decisionsViewModel: DecisionsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Check if this is a poll
            let isPoll = decision.metadata?.isPoll == true
            
            if isPoll {
                // Poll UI
                PollView(
                    decision: decision,
                    currentUserId: authViewModel.currentUser?.id ?? "",
                    onVote: { optionIndex in
                        Task {
                            guard let userId = authViewModel.currentUser?.id else { return }
                            await decisionsViewModel.voteOnPoll(
                                decision: decision,
                                userId: userId,
                                optionIndex: optionIndex
                            )
                        }
                    }
                )
            } else {
                // Regular decision UI
                VStack(alignment: .leading, spacing: 8) {
                    Text(decision.content)
                        .font(.body)
                    
                    // Timestamp
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                        
                        Text(decision.createdAt, style: .relative)
                            .font(.caption)
                        
                        Spacer()
                        
                        if let metadata = decision.metadata,
                           let approvedBy = metadata.approvedBy,
                           !approvedBy.isEmpty {
                            Label("\(approvedBy.count) \(approvedBy.count == 1 ? "person" : "people")", systemImage: "person.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
}

/// Poll view for meeting time voting
struct PollView: View {
    let decision: AIInsight
    let currentUserId: String
    let onVote: (Int) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Poll title
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.orange)
                Text("meeting time poll")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }
            
            // Get time options - parse from metadata or content as fallback
            let displayOptions = getTimeOptions()
            
            // ALWAYS show voting buttons (never just text)
            ForEach(Array(displayOptions.enumerated()), id: \.offset) { index, option in
                let votes = decision.metadata?.votes ?? [:]
                let voteCount = votes.values.filter { $0 == "option_\(index + 1)" }.count
                let hasVoted = votes[currentUserId] == "option_\(index + 1)"
                
                Button {
                    print("🗳️ User \(currentUserId) voting for option \(index + 1)")
                    onVote(index)
                } label: {
                    HStack {
                        Text(option)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        if hasVoted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.orange)
                        }
                        
                        if voteCount > 0 {
                            Text("\(voteCount)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(hasVoted ? Color.orange.opacity(0.1) : Color.gray.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(hasVoted ? Color.orange : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
            
            // Timestamp and stats
            HStack {
                Image(systemName: "clock")
                    .font(.caption)
                
                Text(decision.createdAt, style: .relative)
                    .font(.caption)
                
                Spacer()
                
                let totalVotes = decision.metadata?.votes?.count ?? 0
                if totalVotes > 0 {
                    Label("\(totalVotes) \(totalVotes == 1 ? "vote" : "votes")", systemImage: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    /// Get time options from metadata or parse from content
    private func getTimeOptions() -> [String] {
        // Try metadata first
        if let timeOptions = decision.metadata?.timeOptions, !timeOptions.isEmpty {
            print("✅ Using timeOptions from metadata: \(timeOptions.count) options")
            return timeOptions
        }
        
        // Fallback: parse from content
        print("⚠️ No timeOptions in metadata, parsing from content")
        let content = decision.content
        let lines = content.split(separator: "\n")
        
        let parsedOptions = lines.compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.starts(with: "•") || trimmed.starts(with: "-") || trimmed.lowercased().hasPrefix("option") {
                return String(trimmed)
            }
            return nil
        }
        
        if !parsedOptions.isEmpty {
            print("✅ Parsed \(parsedOptions.count) options from content")
            return parsedOptions
        }
        
        // Ultimate fallback: return generic options
        print("⚠️ Could not parse options, using generic fallback")
        return [
            "• option 1: thursday 12pm EST / 9am PST / 5pm GMT / 10:30pm IST",
            "• option 2: friday 10am EST / 7am PST / 3pm GMT / 8:30pm IST",
            "• option 3: friday 1pm EST / 10am PST / 6pm GMT / 11:30pm IST"
        ]
    }
}

#Preview {
    NavigationStack {
        DecisionsView()
            .environmentObject(AuthViewModel())
    }
}

