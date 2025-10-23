//
//  ActionItemsView.swift
//  messageAI
//
//  Created by MessageAI Team
//  View for managing action items in a conversation
//

import SwiftUI

struct ActionItemsView: View {
    let conversationId: String
    let currentUserId: String
    
    @StateObject private var viewModel = ActionItemsViewModel()
    @State private var showAddItem = false
    @State private var editingItem: ActionItem?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.actionItems.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "checklist")
                            .font(.system(size: 60))
                            .foregroundStyle(.orange.opacity(0.3))
                        
                        Text("no action items")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("tap the magic wand to extract tasks from your conversation")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        if viewModel.isExtracting {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("ai extracting action items...")
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                            }
                            .padding(.top, 8)
                        }
                    }
                } else {
                    // Action items list
                    List {
                        // Active items
                        if activeItems.count > 0 {
                            Section("active (\(activeItems.count))") {
                                ForEach(activeItems) { item in
                                    ActionItemRow(
                                        item: item,
                                        onToggle: {
                                            Task {
                                                await viewModel.toggleCompletion(item, conversationId: conversationId)
                                            }
                                        },
                                        onEdit: {
                                            editingItem = item
                                        },
                                        onDelete: {
                                            Task {
                                                await viewModel.deleteActionItem(item, conversationId: conversationId)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        
                        // Completed items
                        if completedItems.count > 0 {
                            Section("completed (\(completedItems.count))") {
                                ForEach(completedItems) { item in
                                    ActionItemRow(
                                        item: item,
                                        onToggle: {
                                            Task {
                                                await viewModel.toggleCompletion(item, conversationId: conversationId)
                                            }
                                        },
                                        onEdit: {
                                            editingItem = item
                                        },
                                        onDelete: {
                                            Task {
                                                await viewModel.deleteActionItem(item, conversationId: conversationId)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("action items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        // AI extraction button
                        Button {
                            Task {
                                await viewModel.extractActionItems(
                                    conversationId: conversationId,
                                    currentUserId: currentUserId
                                )
                            }
                        } label: {
                            if viewModel.isExtracting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .disabled(viewModel.isExtracting)
                        
                        // Manual add button
                        Button {
                            showAddItem = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddActionItemView(
                    conversationId: conversationId,
                    currentUserId: currentUserId,
                    onCreate: { title, assignee, dueDate in
                        Task {
                            await viewModel.createActionItem(
                                conversationId: conversationId,
                                title: title,
                                assignee: assignee,
                                dueDate: dueDate,
                                currentUserId: currentUserId
                            )
                            showAddItem = false
                        }
                    }
                )
            }
            .sheet(item: $editingItem) { item in
                EditActionItemView(
                    item: item,
                    onSave: { updatedItem in
                        Task {
                            await viewModel.updateActionItem(updatedItem, conversationId: conversationId)
                            editingItem = nil
                        }
                    }
                )
            }
            .alert("error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("ok") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onAppear {
                viewModel.subscribeToActionItems(conversationId: conversationId)
            }
            .onDisappear {
                viewModel.cleanup()
            }
        }
    }
    
    // MARK: - Filtered Items
    
    private var activeItems: [ActionItem] {
        viewModel.actionItems.filter { !$0.completed }
    }
    
    private var completedItems: [ActionItem] {
        viewModel.actionItems.filter { $0.completed }
    }
}

/// Action item row view
struct ActionItemRow: View {
    let item: ActionItem
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Completion checkbox
            Button(action: onToggle) {
                Image(systemName: item.statusIcon)
                    .font(.title3)
                    .foregroundStyle(item.statusColor)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(item.title)
                    .font(.body)
                    .strikethrough(item.completed)
                    .foregroundStyle(item.completed ? .secondary : .primary)
                
                // Metadata
                HStack(spacing: 12) {
                    if let assignee = item.assignee {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                            Text(assignee)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                    
                    if let dueDateText = item.dueDateText {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(dueDateText)
                                .font(.caption)
                        }
                        .foregroundStyle(isOverdue ? .red : .secondary)
                    }
                    
                    if item.confidence < 1.0 {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                            Text("\(Int(item.confidence * 100))%")
                                .font(.caption)
                        }
                        .foregroundStyle(.orange)
                    }
                }
            }
            
            Spacer()
            
            // Actions menu
            Menu {
                Button {
                    onEdit()
                } label: {
                    Label("edit", systemImage: "pencil")
                }
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var isOverdue: Bool {
        guard let dueDate = item.dueDate else {
            return false
        }
        return dueDate < Date() && !item.completed
    }
}

/// Add action item view
struct AddActionItemView: View {
    let conversationId: String
    let currentUserId: String
    let onCreate: (String, String?, Date?) -> Void
    
    @State private var title = ""
    @State private var assignee = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("task details") {
                    TextField("what needs to be done?", text: $title, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("assignee (optional)") {
                    TextField("who will do this?", text: $assignee)
                }
                
                Section("due date") {
                    Toggle("set due date", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker("due date", selection: $dueDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("new action item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") {
                        onCreate(
                            title,
                            assignee.isEmpty ? nil : assignee,
                            hasDueDate ? dueDate : nil
                        )
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

/// Edit action item view
struct EditActionItemView: View {
    let item: ActionItem
    let onSave: (ActionItem) -> Void
    
    @State private var title: String
    @State private var assignee: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @Environment(\.dismiss) private var dismiss
    
    init(item: ActionItem, onSave: @escaping (ActionItem) -> Void) {
        self.item = item
        self.onSave = onSave
        _title = State(initialValue: item.title)
        _assignee = State(initialValue: item.assignee ?? "")
        _hasDueDate = State(initialValue: item.dueDate != nil)
        _dueDate = State(initialValue: item.dueDate ?? Date())
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("task details") {
                    TextField("what needs to be done?", text: $title, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("assignee (optional)") {
                    TextField("who will do this?", text: $assignee)
                }
                
                Section("due date") {
                    Toggle("set due date", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker("due date", selection: $dueDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("edit action item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") {
                        var updatedItem = item
                        updatedItem.title = title
                        updatedItem.assignee = assignee.isEmpty ? nil : assignee
                        updatedItem.dueDate = hasDueDate ? dueDate : nil
                        onSave(updatedItem)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ActionItemsView(
            conversationId: "test123",
            currentUserId: "user1"
        )
    }
}

