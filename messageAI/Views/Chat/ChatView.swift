//
//  ChatView.swift
//  messageAI
//
//  Created by MessageAI Team
//  Main chat view for messaging
//

import SwiftUI

struct ChatView: View {
    let conversation: Conversation
    let currentUserId: String
    
    @StateObject private var viewModel = ChatViewModel()
    @StateObject private var aiViewModel = AIInsightsViewModel()
    @State private var messageText = ""
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showFullScreenImage: Message?
    @State private var showAIMenu = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Network status banner
            NetworkBanner()
            
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if viewModel.isLoading && viewModel.messages.isEmpty {
                            ProgressView()
                                .padding()
                        }
                        
                        // AI Insights
                        ForEach(aiViewModel.insights) { insight in
                            AIInsightCardView(insight: insight) {
                                Task {
                                    await aiViewModel.dismissInsight(
                                        insightId: insight.id,
                                        conversationId: conversation.id
                                    )
                                }
                            }
                        }
                        
                        // Messages
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(
                                message: message,
                                isFromCurrentUser: message.isFromCurrentUser(userId: currentUserId),
                                showSenderName: conversation.type == .group
                            )
                            .id(message.id)
                            .contextMenu {
                                if message.status == .failed {
                                    Button {
                                        Task {
                                            await viewModel.retryMessage(message)
                                        }
                                    } label: {
                                        Label("retry", systemImage: "arrow.clockwise")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    // Auto-scroll to bottom on new message
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    // Scroll to bottom on appear
                    if let lastMessage = viewModel.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            
            // Message input
            MessageInputView(
                text: $messageText,
                onSend: sendMessage,
                onImageTap: {
                    showImagePicker = true
                },
                isSending: viewModel.isSending,
                isUploadingImage: viewModel.isUploadingImage
            )
        }
        .navigationTitle(conversation.displayName(for: currentUserId))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(conversation.displayName(for: currentUserId))
                        .font(.headline)
                    
                    if conversation.type == .group {
                        Text("\(conversation.participantIds.count) members")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Task {
                            try? await aiViewModel.summarize(conversationId: conversation.id)
                        }
                    } label: {
                        Label("summarize", systemImage: "doc.text")
                    }
                    
                    Button {
                        Task {
                            try? await aiViewModel.extractActionItems(conversationId: conversation.id)
                        }
                    } label: {
                        Label("action items", systemImage: "checklist")
                    }
                } label: {
                    Image(systemName: "sparkles")
                }
                .disabled(aiViewModel.isLoading)
            }
        }
        .onAppear {
            viewModel.loadMessages(
                conversationId: conversation.id,
                currentUserId: currentUserId
            )
            aiViewModel.subscribeToInsights(conversationId: conversation.id)
        }
        .onDisappear {
            viewModel.cleanup()
            aiViewModel.cleanup()
        }
        .confirmationDialog("add photo", isPresented: $showImagePicker) {
            Button("take photo") {
                // Camera functionality will be added
            }
            
            Button("choose from library") {
                // For now, just a placeholder
                // Full implementation in next iteration
            }
            
            Button("cancel", role: .cancel) {}
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                sendImage(image)
                selectedImage = nil
            }
        }
        .sheet(item: $showFullScreenImage) { message in
            FullScreenImageView(message: message)
        }
        .alert("error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("ok") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    // MARK: - Send Message
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Get current user info from conversation
        let participant = conversation.participantDetails[currentUserId]
        
        Task {
            await viewModel.sendMessage(
                text: text,
                senderId: currentUserId,
                senderName: participant?.displayName ?? "You",
                senderPhotoURL: participant?.photoURL
            )
        }
    }
    
    // MARK: - Send Image
    
    private func sendImage(_ image: UIImage) {
        let participant = conversation.participantDetails[currentUserId]
        
        Task {
            await viewModel.sendImageMessage(
                image: image,
                caption: "",
                senderId: currentUserId,
                senderName: participant?.displayName ?? "You",
                senderPhotoURL: participant?.photoURL
            )
        }
    }
}

/// Full-screen image viewer
struct FullScreenImageView: View {
    let message: Message
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let imageURL = message.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = lastScale * value
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                        
                                        // Reset if too small or too large
                                        if scale < 1 {
                                            withAnimation {
                                                scale = 1
                                                lastScale = 1
                                            }
                                        } else if scale > 4 {
                                            withAnimation {
                                                scale = 4
                                                lastScale = 4
                                            }
                                        }
                                    }
                            )
                            .onTapGesture(count: 2) {
                                // Double tap to reset zoom
                                withAnimation {
                                    scale = 1
                                    lastScale = 1
                                }
                            }
                    } placeholder: {
                        ProgressView()
                            .tint(.white)
                    }
                }
            }
            .navigationTitle(message.senderName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(
            conversation: Conversation(
                id: "1",
                type: .direct,
                participantIds: ["user1", "user2"],
                participantDetails: [
                    "user1": ParticipantDetail(displayName: "You"),
                    "user2": ParticipantDetail(displayName: "Alice Smith")
                ]
            ),
            currentUserId: "user1"
        )
    }
}

