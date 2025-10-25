//
//  ResponseSuggestionsCard.swift
//  messageAI
//
//  Advanced AI Feature: Smart Response Suggestions
//  Minimal compact badge that expands to show suggestions
//

import SwiftUI

/// Minimal compact card displaying response suggestions
struct ResponseSuggestionsCard: View {
    @ObservedObject var viewModel: ResponseSuggestionsViewModel
    let onSelectSuggestion: (String) -> Void

    @State private var showSheet = false

    var body: some View {
        // ============================================
        // COMPACT BADGE (MINIMAL UI)
        // ============================================
        Button(action: {
            if !viewModel.isLoading && !viewModel.suggestions.isEmpty {
                showSheet = true
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(.blue)

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("generating...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let errorMessage = viewModel.errorMessage {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("failed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("ai suggestions (\(viewModel.suggestions.count))")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Image(systemName: "chevron.up")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Dismiss button
                Button(action: {
                    viewModel.dismissSuggestions()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.bottom, 4)
        .sheet(isPresented: $showSheet) {
            SuggestionsSheet(
                viewModel: viewModel,
                onSelectSuggestion: { suggestion in
                    onSelectSuggestion(suggestion)
                    showSheet = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

/// Bottom sheet showing all suggestions
struct SuggestionsSheet: View {
    @ObservedObject var viewModel: ResponseSuggestionsViewModel
    let onSelectSuggestion: (String) -> Void

    @State private var showFeedback = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Header description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("choose a response")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("ai-generated suggestions based on conversation context")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top)

                    // Suggestions list
                    ForEach(viewModel.suggestions) { suggestion in
                        SuggestionButton(
                            suggestion: suggestion,
                            action: {
                                onSelectSuggestion(suggestion.text)
                            }
                        )
                        .padding(.horizontal)
                    }

                    // Feedback section
                    if showFeedback {
                        feedbackSection
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !showFeedback {
                        Button(action: { showFeedback.toggle() }) {
                            Image(systemName: "hand.thumbsup")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Feedback Section

    private var feedbackSection: some View {
        VStack(spacing: 12) {
            Text("were these suggestions helpful?")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                // Thumbs up
                Button(action: {
                    print("👍 suggestions were helpful")
                    showFeedback = false
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.thumbsup.fill")
                        Text("helpful")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                // Thumbs down
                Button(action: {
                    print("👎 suggestions were not helpful")
                    showFeedback = false
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.thumbsdown.fill")
                        Text("not helpful")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.red)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#if DEBUG
struct ResponseSuggestionsCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            
            ResponseSuggestionsCard(
                viewModel: {
                    let vm = ResponseSuggestionsViewModel()
                    vm.suggestions = ResponseSuggestion.samples
                    return vm
                }(),
                onSelectSuggestion: { text in
                    print("selected: \(text)")
                }
            )
        }
        .background(Color(.systemBackground))
    }
}
#endif

