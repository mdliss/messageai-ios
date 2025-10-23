//
//  SearchView.swift
//  messageAI
//
//  Created by MessageAI Team
//  Search view for finding messages
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = SearchViewModel()
    @State private var searchText = ""
    @State private var debounceTask: Task<Void, Never>?
    @State private var selectedConversation: (conversationId: String, messageId: String)?
    @State private var navigateToConversation: Conversation?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isSearching {
                    // AI search loading state
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.purple)
                            Text("ai searching messages...")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.purple)
                        }
                        
                        Text("using semantic understanding to find relevant messages")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else if searchText.isEmpty {
                    // Empty state with AI examples
                    VStack(spacing: 20) {
                        Image(systemName: "sparkles.rectangle.stack")
                            .font(.system(size: 60))
                            .foregroundStyle(.purple.opacity(0.3))
                        
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.purple)
                                Text("ai powered search")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                            }
                            
                            Text("search using natural language - no exact keywords needed")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("try queries like:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                ExampleQueryRow(text: "what did sarah say about the deadline")
                                ExampleQueryRow(text: "when is the meeting scheduled")
                                ExampleQueryRow(text: "who mentioned the budget")
                                ExampleQueryRow(text: "messages about basketball")
                            }
                        }
                        .padding()
                        .background(Color.purple.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                } else if viewModel.aiSearchResults.isEmpty && viewModel.searchResults.isEmpty {
                    // No results
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray.opacity(0.3))
                        
                        Text("no results found")
                            .font(.headline)
                        
                        Text("try different keywords or a more general query")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    // Results list (AI or keyword)
                    List {
                        // Show RAG answers first (grouped by conversation)
                        if !viewModel.ragAnswers.isEmpty {
                            Section {
                                ForEach(Array(viewModel.ragAnswers.keys.sorted()), id: \.self) { conversationId in
                                    if let answer = viewModel.ragAnswers[conversationId] {
                                        RAGAnswerCard(
                                            answer: answer,
                                            conversationId: conversationId
                                        )
                                    }
                                }
                            } header: {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(.purple)
                                    Text("ai answers")
                                        .textCase(.none)
                                }
                            }
                        }
                        
                        if !viewModel.aiSearchResults.isEmpty {
                            // Referenced Messages (sources AI used to generate answer)
                            Section {
                                ForEach(viewModel.aiSearchResults) { result in
                                    Button {
                                        handleSelectResult(result)
                                    } label: {
                                        AISearchResultRow(result: result)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } header: {
                                HStack {
                                    Image(systemName: "doc.text.magnifyingglass")
                                        .foregroundStyle(.blue)
                                    Text("referenced messages (\(viewModel.aiSearchResults.count))")
                                        .textCase(.none)
                                }
                                .font(.subheadline)
                            } footer: {
                                Text("these messages were used by AI to generate the answer above. percentages show similarity to your search.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            // Keyword Search Results (fallback)
                            ForEach(Array(viewModel.groupedResults().keys.sorted()), id: \.self) { conversationId in
                                if let messages = viewModel.groupedResults()[conversationId] {
                                    Section {
                                        ForEach(messages) { message in
                                            SearchResultView(
                                                message: message,
                                                searchQuery: searchText
                                            )
                                        }
                                    } header: {
                                        Text("\(messages.count) \(messages.count == 1 ? "result" : "results")")
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("done") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "search messages with AI")
            .onChange(of: searchText) { oldValue, newValue in
                print("🔍 Search text changed: \"\(oldValue)\" → \"\(newValue)\"")
                
                // Cancel previous search
                debounceTask?.cancel()
                
                // Debounce search (wait 500ms after user stops typing)
                debounceTask = Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    
                    guard !Task.isCancelled else { 
                        print("🔍 Search task cancelled")
                        return 
                    }
                    
                    print("🔍 Triggering AI search for: \"\(newValue)\"")
                    await viewModel.search(query: newValue)
                }
            }
            .onAppear {
                // Set current user ID for AI search
                viewModel.currentUserId = authViewModel.currentUser?.id
                print("🔍 ═══════════════════════════════════════")
                print("🔍 SearchView APPEARED")
                print("🔍 User ID: \(authViewModel.currentUser?.id ?? "NOT SET")")
                print("🔍 AI Search: \(viewModel.useAISearch ? "ENABLED" : "DISABLED")")
                print("🔍 ═══════════════════════════════════════")
            }
            .onDisappear {
                debounceTask?.cancel()
            }
            .navigationDestination(item: $navigateToConversation) { conversation in
                if let currentUserId = authViewModel.currentUser?.id {
                    ChatView(
                        conversation: conversation,
                        currentUserId: currentUserId
                    )
                }
            }
        }
    }
    
    // MARK: - Handle Result Selection
    
    private func handleSelectResult(_ result: AISearchResult) {
        print("🔍 User tapped result for conversation: \(result.conversationId)")
        
        Task {
            do {
                // Fetch the conversation details
                let conversation = try await FirestoreService.shared.getConversation(result.conversationId)
                
                await MainActor.run {
                    navigateToConversation = conversation
                    print("✅ Navigating to conversation: \(conversation.displayName(for: authViewModel.currentUser?.id ?? ""))")
                }
            } catch {
                print("❌ Failed to fetch conversation: \(error.localizedDescription)")
            }
        }
    }
}

/// Search result row view
struct SearchResultView: View {
    let message: Message
    let searchQuery: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Sender and timestamp
            HStack {
                Text(message.senderName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(message.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Message text with highlighted query
            Text(highlightedText())
                .font(.body)
                .lineLimit(3)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Highlight Search Query
    
    private func highlightedText() -> AttributedString {
        var attributedString = AttributedString(message.text)
        
        if let range = attributedString.range(of: searchQuery, options: .caseInsensitive) {
            attributedString[range].backgroundColor = .yellow.opacity(0.3)
            attributedString[range].foregroundColor = .primary
        }
        
        return attributedString
    }
}

/// AI search result row
struct AISearchResultRow: View {
    let result: AISearchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Sender and timestamp
            HStack {
                Text(result.senderName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text(result.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Message snippet
            Text(result.snippet)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            
            // Relevance indicator
            HStack(spacing: 6) {
                // Relevance stars
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Image(systemName: index < Int(result.score * 5) ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
                
                Text("\(Int(result.score * 100))% match")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Image(systemName: "arrow.up.forward.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                
                Text("view in chat")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

/// RAG answer card view
struct RAGAnswerCard: View {
    let answer: String
    let conversationId: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with AI sparkles
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                    .font(.title3)
                
                Text("AI Answer")
                    .font(.headline)
                    .foregroundStyle(.purple)
                
                Spacer()
            }
            
            // Answer text
            Text(answer)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(isExpanded ? nil : 5)
            
            // Expand/collapse button if text is long
            if answer.count > 200 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text(isExpanded ? "show less" : "show more")
                            .font(.caption)
                            .foregroundStyle(.purple)
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }
}

/// Example query row for empty state
struct ExampleQueryRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .font(.caption)
                .foregroundStyle(.purple.opacity(0.6))
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SearchView()
        .environmentObject(AuthViewModel())
}

