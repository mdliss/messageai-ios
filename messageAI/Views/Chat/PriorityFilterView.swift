//
//  PriorityFilterView.swift
//  messageAI
//
//  Created by MessageAI Team
//  View for filtering and displaying priority messages
//

import SwiftUI
import FirebaseFirestore

struct PriorityFilterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = PriorityFilterViewModel()
    @State private var selectedPriority: MessagePriority? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Priority filter pills
                HStack(spacing: 12) {
                    FilterPill(
                        title: "all priority",
                        icon: "flag.fill",
                        color: .purple,
                        isSelected: selectedPriority == nil,
                        count: viewModel.allPriorityMessages.count
                    ) {
                        selectedPriority = nil
                    }
                    
                    FilterPill(
                        title: "urgent",
                        icon: "exclamationmark.triangle.fill",
                        color: .red,
                        isSelected: selectedPriority == .urgent,
                        count: viewModel.urgentMessages.count
                    ) {
                        selectedPriority = .urgent
                    }
                    
                    FilterPill(
                        title: "high",
                        icon: "circle.fill",
                        color: .yellow,
                        isSelected: selectedPriority == .high,
                        count: viewModel.highPriorityMessages.count
                    ) {
                        selectedPriority = .high
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                Divider()
                
                // Messages list
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else if filteredMessages.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: selectedPriority == .urgent ? "exclamationmark.triangle" : "flag")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray.opacity(0.3))
                        
                        Text("no \(priorityLabel) messages")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("priority messages will appear here")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(groupedByConversation(), id: \.key) { conversationId, messages in
                            Section {
                                ForEach(messages) { priorityMessage in
                                    PriorityMessageRow(
                                        message: priorityMessage.message,
                                        conversationName: viewModel.conversationNames[conversationId] ?? "Unknown"
                                    )
                                }
                            } header: {
                                Text(viewModel.conversationNames[conversationId] ?? "Unknown")
                                    .font(.caption)
                                    .textCase(.none)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("priority messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let userId = authViewModel.currentUser?.id {
                    viewModel.loadPriorityMessages(userId: userId)
                }
            }
            .refreshable {
                if let userId = authViewModel.currentUser?.id {
                    viewModel.loadPriorityMessages(userId: userId)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var priorityLabel: String {
        guard let priority = selectedPriority else {
            return "priority"
        }
        
        switch priority {
        case .urgent:
            return "urgent"
        case .high:
            return "high priority"
        case .normal:
            return "normal"
        }
    }
    
    private var filteredMessages: [PriorityMessage] {
        guard let selectedPriority = selectedPriority else {
            return viewModel.allPriorityMessages
        }
        
        return viewModel.allPriorityMessages.filter { $0.message.priority == selectedPriority }
    }
    
    private func groupedByConversation() -> [(key: String, value: [PriorityMessage])] {
        let grouped = Dictionary(grouping: filteredMessages) { $0.message.conversationId }
        return grouped.sorted { $0.value.first?.message.createdAt ?? Date() > $1.value.first?.message.createdAt ?? Date() }
    }
}

/// Filter pill button
struct FilterPill: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                
                Text(title)
                    .font(.subheadline.weight(.semibold))
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : color)
                        .cornerRadius(10)
                }
            }
            .foregroundStyle(isSelected ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : color.opacity(0.1))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(color, lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Priority message row
struct PriorityMessageRow: View {
    let message: Message
    let conversationName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Priority badge
            HStack(spacing: 4) {
                priorityIcon
                Text(priorityLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(priorityColor)
            }
            
            // Message text
            Text(message.text)
                .font(.body)
                .lineLimit(3)
            
            // Metadata
            HStack {
                Text(message.senderName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("•")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(message.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Image(systemName: "arrow.up.forward.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var priorityIcon: some View {
        if message.priority == .urgent {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        } else if message.priority == .high {
            Image(systemName: "circle.fill")
                .foregroundStyle(.yellow)
        } else {
            Image(systemName: "flag.fill")
                .foregroundStyle(.gray)
        }
    }
    
    private var priorityLabel: String {
        message.priority?.rawValue ?? "priority"
    }
    
    private var priorityColor: Color {
        guard let priority = message.priority else {
            return .gray
        }
        
        switch priority {
        case .urgent:
            return .red
        case .high:
            return .orange
        case .normal:
            return .gray
        }
    }
}

/// Priority message with conversation context
struct PriorityMessage: Identifiable {
    let id: String
    let message: Message
    let conversationId: String
}

#Preview {
    NavigationStack {
        PriorityFilterView()
            .environmentObject(AuthViewModel())
    }
}

