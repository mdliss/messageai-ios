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
                        if !viewModel.aiSearchResults.isEmpty {
                            // AI Search Results
                            Section {
                                ForEach(viewModel.aiSearchResults) { result in
                                    AISearchResultRow(result: result)
                                }
                            } header: {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(.purple)
                                    Text("ai search results (\(viewModel.aiSearchResults.count))")
                                        .textCase(.none)
                                }
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

