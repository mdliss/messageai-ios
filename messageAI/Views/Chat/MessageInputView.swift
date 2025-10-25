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
    let onImageTap: () -> Void
    let onVoiceSend: (URL, TimeInterval) -> Void
    let isSending: Bool
    let isUploadingImage: Bool

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Image button
            Button {
                onImageTap()
            } label: {
                Image(systemName: "photo")
                    .foregroundStyle(.blue)
                    .font(.title3)
            }
            .disabled(isSending || isUploadingImage)
            
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
            
            // Send or Voice button
            if isSendEnabled {
                // Send button (when text is entered)
                Button {
                    handleSend()
                } label: {
                    Group {
                        if isSending || isUploadingImage {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.blue)
                    .clipShape(Circle())
                }
                .disabled(isSending || isUploadingImage)
            } else {
                // Voice button (when no text)
                VoiceRecorderView(
                    onSend: { url, duration in
                        onVoiceSend(url, duration)
                    },
                    onCancel: {
                        // Just dismiss
                    }
                )
            }
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
            onImageTap: {},
            onVoiceSend: { _, _ in },
            isSending: false,
            isUploadingImage: false
        )
    }
}

