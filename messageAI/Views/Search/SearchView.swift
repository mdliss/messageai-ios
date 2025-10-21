//
//  SearchView.swift
//  messageAI
//
//  Created by MessageAI Team
//  Search view for finding messages
//

import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isSearching {
                    ProgressView()
                } else if searchText.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray.opacity(0.3))
                        
                        Text("search messages")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("find messages across all conversations")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else if viewModel.searchResults.isEmpty {
                    // No results
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray.opacity(0.3))
                        
                        Text("no results found")
                            .font(.headline)
                        
                        Text("try different keywords")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // Results list
                    List {
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
            .searchable(text: $searchText, prompt: "search messages")
            .onChange(of: searchText) { _, newValue in
                Task {
                    await viewModel.search(query: newValue)
                }
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

#Preview {
    SearchView()
}

