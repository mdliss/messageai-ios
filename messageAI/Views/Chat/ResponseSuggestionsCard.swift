//
//  ResponseSuggestionsCard.swift
//  messageAI
//
//  Advanced AI Feature: Smart Response Suggestions
//  Card displaying AI-generated response suggestions
//

import SwiftUI

/// Card displaying response suggestions for a message
struct ResponseSuggestionsCard: View {
    @ObservedObject var viewModel: ResponseSuggestionsViewModel
    let onSelectSuggestion: (String) -> Void
    
    @State private var showFeedback = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ============================================
            // HEADER
            // ============================================
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.body)
                    .foregroundColor(.blue)
                
                Text("ai suggestions")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Feedback button (optional)
                if !viewModel.suggestions.isEmpty && !showFeedback {
                    Button(action: { showFeedback.toggle() }) {
                        Image(systemName: "hand.thumbsup")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
                
                // Dismiss button
                Button(action: viewModel.dismissSuggestions) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            
            // ============================================
            // LOADING STATE
            // ============================================
            if viewModel.isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("generating suggestions...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            
            // ============================================
            // ERROR STATE
            // ============================================
            else if let errorMessage = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            // ============================================
            // SUGGESTIONS LIST
            // ============================================
            else {
                ForEach(viewModel.suggestions) { suggestion in
                    SuggestionButton(
                        suggestion: suggestion,
                        action: {
                            onSelectSuggestion(suggestion.text)
                        }
                    )
                }
                
                // Feedback section (if shown)
                if showFeedback {
                    feedbackSection
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
    
    // MARK: - Feedback Section
    
    private var feedbackSection: some View {
        HStack(spacing: 16) {
            Text("were these suggestions helpful?")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Thumbs up
            Button(action: {
                // Record helpful feedback
                print("👍 suggestions were helpful")
                showFeedback = false
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "hand.thumbsup.fill")
                    Text("yes")
                }
                .font(.caption)
                .foregroundColor(.green)
            }
            .buttonStyle(.plain)
            
            // Thumbs down
            Button(action: {
                // Record not helpful feedback
                print("👎 suggestions were not helpful")
                showFeedback = false
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "hand.thumbsdown.fill")
                    Text("no")
                }
                .font(.caption)
                .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
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

