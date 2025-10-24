//
//  SuggestionButton.swift
//  messageAI
//
//  Advanced AI Feature: Smart Response Suggestions
//  Individual suggestion button component
//

import SwiftUI

/// Button displaying a single response suggestion
struct SuggestionButton: View {
    let suggestion: ResponseSuggestion
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            action()
        }) {
            HStack(alignment: .top, spacing: 12) {
                // Type icon
                Image(systemName: suggestion.type.icon)
                    .font(.title3)
                    .foregroundColor(suggestion.type.color)
                    .frame(width: 24, height: 24)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Suggestion text
                    Text(suggestion.text)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Reasoning (why this suggestion fits)
                    Text(suggestion.reasoning)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(suggestion.type.color.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - Preview

#if DEBUG
struct SuggestionButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            SuggestionButton(
                suggestion: ResponseSuggestion.sampleApprove,
                action: { print("approve tapped") }
            )
            
            SuggestionButton(
                suggestion: ResponseSuggestion.sampleConditional,
                action: { print("conditional tapped") }
            )
            
            SuggestionButton(
                suggestion: ResponseSuggestion.sampleDecline,
                action: { print("decline tapped") }
            )
            
            SuggestionButton(
                suggestion: ResponseSuggestion.sampleDelegate,
                action: { print("delegate tapped") }
            )
        }
        .padding()
        .background(Color(.systemGray6))
    }
}
#endif

