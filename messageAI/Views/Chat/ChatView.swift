//
//  ChatView.swift
//  messageAI
//
//  Created by MessageAI Team
//  Main chat view for messaging
//

import SwiftUI
import FirebaseAuth

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
    @State private var showOnlyPriority = false  // Priority filter toggle
    @State private var showActionItems = false  // Action items panel
    @State private var onlineStatuses: [String: Bool] = [:]  // Track online status per user
    @State private var presenceListeners: [String: Task<Void, Never>] = [:]
    @Environment(\.dismiss) private var dismiss
    
    private let realtimeDBService = RealtimeDBService.shared
    
    // Computed online count from statuses
    private var onlineCount: Int {
        onlineStatuses.values.filter { $0 == true }.count
    }
    
    // Computed property for filtered messages
    private var displayedMessages: [Message] {
        if showOnlyPriority {
            return viewModel.messages.filter { $0.priority == .urgent || $0.priority == .high }
        }
        return viewModel.messages
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Network status banner
                NetworkBanner()
                
                // Messages list
                ScrollViewReader { proxy in
                    List {
                    // Load older messages indicator
                    if viewModel.hasMoreMessages {
                        HStack {
                            Spacer()
                            if viewModel.isLoadingOlderMessages {
                                ProgressView()
                                    .padding()
                            } else {
                                Button("load older messages") {
                                    Task {
                                        await viewModel.loadOlderMessages()
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding()
                            }
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .onAppear {
                            // Auto-load when scrolling to top
                            Task {
                                await viewModel.loadOlderMessages()
                            }
                        }
                    }
                    
                    if viewModel.isLoading && viewModel.messages.isEmpty {
                        ProgressView()
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    
                    // Priority filter banner
                    if showOnlyPriority {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text("showing urgent messages only")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Button("show all") {
                                withAnimation {
                                    showOnlyPriority = false
                                }
                            }
                            .font(.caption)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                    
                    // Messages (filtered if priority view enabled)
                    ForEach(displayedMessages) { message in
                        MessageBubbleView(
                            message: message,
                            isFromCurrentUser: message.isFromCurrentUser(userId: currentUserId),
                            showSenderName: conversation.type == .group
                        )
                        .id(message.id)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if message.isFromCurrentUser(userId: currentUserId) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteMessage(message, currentUserId: currentUserId)
                                    }
                                } label: {
                                    Label("delete", systemImage: "trash")
                                }
                            }
                        }
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
                            
                            if message.isFromCurrentUser(userId: currentUserId) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteMessage(message, currentUserId: currentUserId)
                                    }
                                } label: {
                                    Label("delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .onChange(of: viewModel.messages.count) { _, _ in
                    // Auto-scroll to bottom on new message (use actual messages, not filtered)
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: showOnlyPriority) { _, _ in
                    // Scroll to bottom when toggling filter
                    if let lastMessage = displayedMessages.last {
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
            
            // Typing indicator
            if !viewModel.typingUsers.isEmpty {
                TypingIndicatorView(
                    typingUsers: viewModel.typingUsers,
                    participantNames: conversation.participantDetails.mapValues { $0.displayName }
                )
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
            .onChange(of: messageText) { _, newValue in
                viewModel.handleTextChange(newValue, currentUserId: currentUserId)
            }
            }
            
            // Floating AI Insights Overlay (bottom)
            VStack(spacing: 8) {
                // Show all insights (summaries filtered by triggeredBy, shown only to requester)
                ForEach(aiViewModel.insights) { insight in
                    let isSchedulingSuggestion = insight.type == .suggestion
                    
                    AIInsightCardView(
                        insight: insight,
                        onDismiss: {
                            Task {
                                await aiViewModel.dismissInsight(
                                    insightId: insight.id,
                                    conversationId: conversation.id,
                                    currentUserId: currentUserId
                                )
                            }
                        },
                        onAcceptSuggestion: isSchedulingSuggestion ? {
                            handleAcceptSuggestion(insight)
                        } : nil
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, 60)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: aiViewModel.insights.count)
        }
        .navigationTitle(conversation.displayName(for: currentUserId))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(conversation.displayName(for: currentUserId))
                        .font(.headline)
                    
                    if conversation.type == .group {
                        HStack(spacing: 4) {
                            Text("\(conversation.participantIds.count) members")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            if onlineCount > 0 {
                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                HStack(spacing: 3) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 6, height: 6)
                                    
                                    Text("\(onlineCount) online")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    // Action Items button
                    Button {
                        showActionItems = true
                    } label: {
                        Image(systemName: "checklist")
                            .foregroundStyle(.orange)
                    }
                    
                    // Priority filter toggle
                    Button {
                        withAnimation {
                            showOnlyPriority.toggle()
                        }
                    } label: {
                        Image(systemName: showOnlyPriority ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                            .foregroundStyle(showOnlyPriority ? .red : .primary)
                    }
                    
                    // AI features menu
                    Menu {
                        Button {
                            Task {
                                // FIXED: Pass currentUserId for per-user summary storage
                                try? await aiViewModel.summarize(
                                    conversationId: conversation.id,
                                    currentUserId: currentUserId
                                )
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
                        
                        Divider()
                        
                        Button {
                            NetworkMonitor.shared.toggleDebugOfflineMode()
                        } label: {
                            Label(
                                NetworkMonitor.shared.debugOfflineMode ? "go online (debug)" : "go offline (debug)",
                                systemImage: NetworkMonitor.shared.debugOfflineMode ? "wifi" : "wifi.slash"
                            )
                        }
                    } label: {
                        Image(systemName: "sparkles")
                    }
                    .disabled(aiViewModel.isLoading)
                }
            }
        }
        .onAppear {
            // Set current conversation in app state
            AppStateService.shared.setCurrentConversation(conversation.id)
            
            viewModel.loadMessages(
                conversationId: conversation.id,
                currentUserId: currentUserId
            )
            aiViewModel.subscribeToInsights(conversationId: conversation.id, currentUserId: currentUserId)
            
            // Subscribe to presence for group chat members
            if conversation.type == .group {
                subscribeToGroupPresence()
            }
        }
        .onDisappear {
            // Clear current conversation from app state
            AppStateService.shared.clearCurrentConversation()
            
            viewModel.cleanup()
            aiViewModel.cleanup()
            
            // Clean up presence listeners
            cleanupPresenceListeners()
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
        .sheet(isPresented: $showActionItems) {
            ActionItemsView(
                conversationId: conversation.id,
                currentUserId: currentUserId
            )
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
        
        // Clear input immediately for better UX
        messageText = ""
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
    
    // MARK: - Handle Scheduling Suggestion
    
    private func handleAcceptSuggestion(_ insight: AIInsight) {
        Task {
            let userName = AuthService.shared.currentFirebaseUser?.displayName ?? "user"
            
            await aiViewModel.acceptSuggestion(
                insight: insight,
                conversationId: conversation.id,
                currentUserId: currentUserId,
                currentUserName: userName
            )
        }
    }
    
    // MARK: - Group Presence Tracking
    
    /// Subscribe to presence for all group members
    private func subscribeToGroupPresence() {
        print("👥 Subscribing to presence for \(conversation.participantIds.count) group members")
        
        // Get all participants except current user
        let otherParticipants = conversation.participantIds.filter { $0 != currentUserId }
        
        // Initialize all as offline first
        for userId in otherParticipants {
            onlineStatuses[userId] = false
        }
        
        // Subscribe to each participant's presence
        for userId in otherParticipants {
            let task = Task {
                for await isOnline in realtimeDBService.observePresence(userId: userId) {
                    await MainActor.run {
                        onlineStatuses[userId] = isOnline
                        
                        let onlineNow = onlineStatuses.values.filter { $0 == true }.count
                        print("👥 Presence update: user \(userId) is \(isOnline ? "ONLINE" : "OFFLINE"), total online: \(onlineNow)/\(otherParticipants.count)")
                    }
                }
            }
            presenceListeners[userId] = task
        }
    }
    
    /// Clean up presence listeners
    private func cleanupPresenceListeners() {
        print("🧹 Cleaning up \(presenceListeners.count) group presence listeners")
        for (_, task) in presenceListeners {
            task.cancel()
        }
        presenceListeners.removeAll()
        onlineStatuses.removeAll()
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

