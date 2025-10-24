//
//  BlockerDashboardView.swift
//  messageAI
//
//  Advanced AI Feature: Proactive Blocker Detection
//  Main dashboard showing all active team blockers
//

import SwiftUI

/// Dashboard displaying active team blockers
struct BlockerDashboardView: View {
    let currentUserId: String
    
    @StateObject private var viewModel = BlockerDashboardViewModel()
    
    var body: some View {
        NavigationView {
            Group {
                // ============================================
                // LOADING STATE
                // ============================================
                if viewModel.isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("loading blockers...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
                
                // ============================================
                // EMPTY STATE
                // ============================================
                else if viewModel.activeBlockers.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 72))
                            .foregroundColor(.green)
                        
                        Text("no active blockers 🎉")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("your team is flowing smoothly")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                // ============================================
                // BLOCKERS LIST
                // ============================================
                else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Summary header
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(viewModel.activeBlockers.count) active blocker\(viewModel.activeBlockers.count == 1 ? "" : "s")")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    
                                    let criticalCount = viewModel.activeBlockers.filter { $0.severity == .critical }.count
                                    let highCount = viewModel.activeBlockers.filter { $0.severity == .high }.count
                                    
                                    if criticalCount > 0 || highCount > 0 {
                                        HStack(spacing: 8) {
                                            if criticalCount > 0 {
                                                HStack(spacing: 4) {
                                                    Circle()
                                                        .fill(Color.red)
                                                        .frame(width: 8, height: 8)
                                                    Text("\(criticalCount) critical")
                                                        .font(.caption)
                                                        .foregroundColor(.red)
                                                }
                                            }
                                            
                                            if highCount > 0 {
                                                HStack(spacing: 4) {
                                                    Circle()
                                                        .fill(Color.orange)
                                                        .frame(width: 8, height: 8)
                                                    Text("\(highCount) high")
                                                        .font(.caption)
                                                        .foregroundColor(.orange)
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                            
                            Divider()
                                .padding(.horizontal)
                            
                            // Blocker cards
                            ForEach(viewModel.activeBlockers) { blocker in
                                BlockerCard(
                                    blocker: blocker,
                                    onResolve: { notes in
                                        Task {
                                            await viewModel.markResolved(
                                                blocker,
                                                notes: notes,
                                                currentUserId: currentUserId
                                            )
                                        }
                                    },
                                    onSnooze: { duration in
                                        Task {
                                            await viewModel.snooze(blocker, duration: duration)
                                        }
                                    },
                                    onMarkFalsePositive: {
                                        Task {
                                            await viewModel.markFalsePositive(blocker)
                                        }
                                    }
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .navigationTitle("team blockers")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.loadActiveBlockers(for: currentUserId)
            }
        }
        .task {
            await viewModel.loadActiveBlockers(for: currentUserId)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct BlockerDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        BlockerDashboardView(currentUserId: "testUser123")
    }
}
#endif

