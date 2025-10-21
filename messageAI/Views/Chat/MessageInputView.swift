//
//  MessageInputView.swift
//  messageAI
//
//  Created by MessageAI Team
//  Message input view for composing messages
//

import SwiftUI

struct MessageInputView: View {
    @Binding var text: String
    let onSend: () -> Void
    let isSending: Bool
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Text input
            TextField("message", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .lineLimit(1...5)
                .focused($isFocused)
                .disabled(isSending)
            
            // Send button
            Button {
                handleSend()
            } label: {
                Group {
                    if isSending {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.up")
                            .fontWeight(.semibold)
                    }
                }
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(isSendEnabled ? Color.blue : Color.gray)
                .clipShape(Circle())
            }
            .disabled(!isSendEnabled || isSending)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Helpers
    
    private var isSendEnabled: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func handleSend() {
        guard isSendEnabled else { return }
        
        onSend()
        
        // Clear text and dismiss keyboard
        text = ""
        isFocused = false
    }
}

#Preview {
    VStack {
        Spacer()
        
        MessageInputView(
            text: .constant(""),
            onSend: {},
            isSending: false
        )
    }
}

