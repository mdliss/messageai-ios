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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Decision content
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

#Preview {
    NavigationStack {
        DecisionsView()
            .environmentObject(AuthViewModel())
    }
}

