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
    let scrollToMessageId: String?
    
    @StateObject private var viewModel = ChatViewModel()
    @StateObject private var aiViewModel = AIInsightsViewModel()
    @StateObject private var suggestionsViewModel = ResponseSuggestionsViewModel()  // NEW: Response suggestions
    @State private var messageText = ""
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showFullScreenImage: Message?
    @State private var showAIMenu = false
    @State private var showOnlyPriority = false  // Priority filter toggle
    @State private var showActionItems = false  // Action items panel
    @State private var onlineStatuses: [String: Bool] = [:]  // Track online status per user
    @State private var presenceListeners: [String: Task<Void, Never>] = [:]
    @State private var highlightedMessageId: String? = nil
    @State private var messageForSuggestions: Message? = nil  // NEW: Track message with suggestions
    @Environment(\.dismiss) private var dismiss
    
    init(conversation: Conversation, currentUserId: String, scrollToMessageId: String? = nil) {
        self.conversation = conversation
        self.currentUserId = currentUserId
        self.scrollToMessageId = scrollToMessageId
    }
    
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
                            showSenderName: conversation.type == .group,
                            isHighlighted: highlightedMessageId == message.id
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
                    // If scrollToMessageId is provided, scroll to that message and highlight it
                    if let targetMessageId = scrollToMessageId {
                        // Small delay to ensure messages are loaded
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            print("🎯 Scrolling to message: \(targetMessageId)")
                            
                            // Scroll to the message
                            proxy.scrollTo(targetMessageId, anchor: .center)
                            
                            // Highlight the message
                            highlightedMessageId = targetMessageId
                            
                            // Auto-fade highlight after 2.5 seconds
                            Task {
                                try? await Task.sleep(nanoseconds: 2_500_000_000)
                                await MainActor.run {
                                    withAnimation(.easeOut(duration: 0.5)) {
                                        highlightedMessageId = nil
                                    }
                                }
                            }
                        }
                    } else {
                        // Normal behavior: Scroll to bottom on appear
                        if let lastMessage = viewModel.messages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
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
            
            // NEW: Response suggestions card
            if !suggestionsViewModel.suggestions.isEmpty || suggestionsViewModel.isLoading {
                ResponseSuggestionsCard(
                    viewModel: suggestionsViewModel,
                    onSelectSuggestion: { suggestionText in
                        // Insert suggestion into message input
                        messageText = suggestionText
                        
                        // Track selection
                        if let message = messageForSuggestions,
                           let selectedSuggestion = suggestionsViewModel.suggestions.first(where: { $0.text == suggestionText }) {
                            suggestionsViewModel.selectSuggestion(
                                selectedSuggestion,
                                messageId: message.id,
                                conversationId: conversation.id
                            )
                        }
                        
                        // Clear suggestions after selection
                        suggestionsViewModel.dismissSuggestions()
                        messageForSuggestions = nil
                    }
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
        .onChange(of: viewModel.messages.count) { oldCount, newCount in
            print("🔔 [SUGGESTIONS] onChange triggered!")
            print("   Old count: \(oldCount), New count: \(newCount)")
            print("   Messages array count: \(viewModel.messages.count)")

            // Check if new message arrived that needs response
            guard newCount > oldCount,
                  let lastMessage = viewModel.messages.last else {
                print("   ❌ no new message or count didn't increase")
                return
            }

            print("📬 new message arrived, checking if suggestions needed...")
            print("   Last message: \(lastMessage.text)")

            // Auto-generate suggestions if message needs response
            if shouldGenerateSuggestions(for: lastMessage) {
                print("✅ message needs response, generating suggestions...")
                generateSuggestionsFor(message: lastMessage)
            } else {
                print("⏭️ message doesn't need suggestions")
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
                senderPhotoURL: participant?.photoURL,
                senderAvatarType: participant?.avatarType,
                senderAvatarId: participant?.avatarId
            )
        }
        
        // Clear input immediately for better UX
        messageText = ""
    }
    
    // MARK: - Smart Response Suggestions
    
    /// Check if a message should trigger response suggestions
    private func shouldGenerateSuggestions(for message: Message) -> Bool {
        print("🔍 [SUGGESTIONS] checking message for trigger conditions...")
        print("   Message ID: \(message.id)")
        print("   Sender ID: \(message.senderId)")
        print("   Current User ID: \(currentUserId)")
        print("   Text: \(message.text)")
        print("   Type: \(message.type)")

        // Don't suggest for messages from current user
        guard message.senderId != currentUserId else {
            print("   ❌ message from current user - skipping")
            return false
        }

        // Don't suggest for image messages
        guard message.type == .text else {
            print("   ❌ not a text message - skipping")
            return false
        }

        let text = message.text.lowercased()
        print("   Text (lowercase): \(text)")

        // Trigger conditions:

        // 1. Message ends with question mark
        if text.hasSuffix("?") {
            print("   ✅ TRIGGER: ends with '?'")
            return true
        }

        // 2. Contains request keywords
        let requestKeywords = [
            "can we", "can you", "could we", "could you",
            "should we", "should you", "would you", "would we",
            "need approval", "need your input", "need you to",
            "waiting for", "waiting on",
            "what do you think", "thoughts on", "your thoughts"
        ]

        for keyword in requestKeywords {
            if text.contains(keyword) {
                print("   ✅ TRIGGER: contains keyword '\(keyword)'")
                return true
            }
        }

        // 3. Message is flagged as priority
        if message.priority == .urgent || message.priority == .high {
            print("   ✅ TRIGGER: priority message (\(message.priority))")
            return true
        }

        // Don't suggest for informational messages
        let fyiKeywords = ["fyi", "for your information", "just letting you know", "heads up"]
        for keyword in fyiKeywords {
            if text.contains(keyword) {
                print("   ❌ FYI keyword found - skipping")
                return false
            }
        }

        print("   ❌ no trigger conditions met")
        return false
    }
    
    /// Generate suggestions for a message
    private func generateSuggestionsFor(message: Message) {
        print("🎯 generating suggestions for message: \(message.id)")
        
        // Dismiss any existing suggestions first
        suggestionsViewModel.dismissSuggestions()
        
        // Track which message we're generating suggestions for
        messageForSuggestions = message
        
        // Generate suggestions
        Task {
            await suggestionsViewModel.generateSuggestions(
                for: message,
                in: conversation.id,
                currentUserId: currentUserId
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
                senderPhotoURL: participant?.photoURL,
                senderAvatarType: participant?.avatarType,
                senderAvatarId: participant?.avatarId
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
            currentUserId: "user1",
            scrollToMessageId: nil
        )
    }
}

