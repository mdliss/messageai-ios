//
//  BlockerCard.swift
//  messageAI
//
//  Advanced AI Feature: Proactive Blocker Detection
//  Card displaying individual blocker information
//

import SwiftUI

/// Card displaying blocker information with resolution actions
struct BlockerCard: View {
    let blocker: Blocker
    let onResolve: (String?) -> Void
    let onSnooze: (TimeInterval) -> Void
    let onMarkFalsePositive: () -> Void
    
    @State private var showingResolveSheet = false
    @State private var resolutionNotes = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ============================================
            // HEADER: Severity + Time
            // ============================================
            HStack {
                Image(systemName: blocker.severity.icon)
                    .font(.body)
                    .foregroundColor(blocker.severity.color)
                
                Text(blocker.severity.displayName)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(blocker.severity.color)
                
                Spacer()
                
                Text(blocker.timeElapsed)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // ============================================
            // BLOCKED PERSON
            // ============================================
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                Text(blocker.blockedUserName)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            // ============================================
            // BLOCKER DESCRIPTION
            // ============================================
            VStack(alignment: .leading, spacing: 4) {
                Text("blocked on:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text(blocker.blockerDescription)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            // ============================================
            // BLOCKER TYPE
            // ============================================
            Text("type: \(blocker.blockerType.displayName)")
                .font(.caption)
                .foregroundColor(.gray)
            
            // ============================================
            // SUGGESTED ACTIONS
            // ============================================
            if !blocker.suggestedActions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("suggested actions:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    ForEach(blocker.suggestedActions, id: \.self) { action in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .font(.caption)
                            Text(action)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.top, 4)
            }
            
            Divider()
            
            // ============================================
            // ACTION BUTTONS
            // ============================================
            HStack(spacing: 12) {
                // Mark resolved
                Button(action: { showingResolveSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("resolve")
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                // Snooze menu
                Menu {
                    Button("1 hour") {
                        onSnooze(3600)
                    }
                    Button("4 hours") {
                        onSnooze(14400)
                    }
                    Button("1 day") {
                        onSnooze(86400)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                        Text("snooze")
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .cornerRadius(8)
                }
                
                // False positive
                Button(action: onMarkFalsePositive) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                        Text("not a blocker")
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(blocker.severity.color.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(blocker.severity.color.opacity(0.3), lineWidth: 2)
        )
        .sheet(isPresented: $showingResolveSheet) {
            NavigationView {
                VStack(spacing: 20) {
                    Text("add resolution notes (optional)")
                        .font(.headline)
                        .padding(.top)
                    
                    TextEditor(text: $resolutionNotes)
                        .frame(height: 120)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    
                    Button(action: {
                        onResolve(resolutionNotes.isEmpty ? nil : resolutionNotes)
                        showingResolveSheet = false
                        resolutionNotes = ""
                    }) {
                        Text("mark as resolved")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .navigationTitle("resolve blocker")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("cancel") {
                            showingResolveSheet = false
                            resolutionNotes = ""
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct BlockerCard_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 16) {
                BlockerCard(
                    blocker: Blocker.sampleCritical,
                    onResolve: { notes in print("resolve: \(notes ?? "no notes")") },
                    onSnooze: { duration in print("snooze: \(duration)") },
                    onMarkFalsePositive: { print("false positive") }
                )
                
                BlockerCard(
                    blocker: Blocker.sampleHigh,
                    onResolve: { _ in },
                    onSnooze: { _ in },
                    onMarkFalsePositive: { }
                )
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
}
#endif

