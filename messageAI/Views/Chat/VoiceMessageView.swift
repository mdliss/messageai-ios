//
//  VoiceMessageView.swift
//  messageAI
//
//  Voice message playback UI with progress bar and transcription
//

import SwiftUI
import AVFoundation
import FirebaseStorage

struct VoiceMessageView: View {
    let message: Message
    let isFromCurrentUser: Bool

    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var audioPlayer: AVAudioPlayer?
    @State private var playbackTimer: Timer?
    @State private var isLoading = false
    @State private var downloadedURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Audio player UI
            HStack(spacing: 12) {
                // Play/Pause button
                Button {
                    togglePlayback()
                } label: {
                    ZStack {
                        Circle()
                            .fill(isFromCurrentUser ? Color.white.opacity(0.3) : Color.blue.opacity(0.2))
                            .frame(width: 40, height: 40)

                        if isLoading {
                            ProgressView()
                                .tint(isFromCurrentUser ? .white : .blue)
                        } else {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(isFromCurrentUser ? .white : .blue)
                        }
                    }
                }
                .disabled(isLoading)

                // Progress bar and duration
                VStack(alignment: .leading, spacing: 4) {
                    // Waveform/Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 2)
                                .fill((isFromCurrentUser ? Color.white : Color.gray).opacity(0.3))
                                .frame(height: 4)

                            // Progress
                            RoundedRectangle(cornerRadius: 2)
                                .fill(isFromCurrentUser ? Color.white : Color.blue)
                                .frame(width: progress * geometry.size.width, height: 4)
                        }
                    }
                    .frame(height: 4)

                    // Time display
                    Text(timeDisplay)
                        .font(.caption2)
                        .foregroundStyle(isFromCurrentUser ? .white.opacity(0.8) : .secondary)
                }
            }

            // Transcription (if available)
            if let transcription = message.transcription, !transcription.isEmpty {
                if transcription == "[Transcription failed]" {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption2)
                        Text("Transcription failed")
                            .font(.caption)
                    }
                    .foregroundStyle(isFromCurrentUser ? .white.opacity(0.7) : .secondary)
                } else {
                    Text(transcription)
                        .font(.callout)
                        .foregroundStyle(isFromCurrentUser ? .white : .primary)
                        .textSelection(.enabled)
                }
            } else if message.transcription == nil {
                // Still transcribing
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(isFromCurrentUser ? .white : .gray)
                    Text("Transcribing...")
                        .font(.caption)
                        .foregroundStyle(isFromCurrentUser ? .white.opacity(0.7) : .secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minWidth: 220)
        .onDisappear {
            stopPlayback()
        }
    }

    // MARK: - Computed Properties

    private var progress: CGFloat {
        guard let duration = message.duration, duration > 0 else { return 0 }
        return CGFloat(currentTime / duration)
    }

    private var timeDisplay: String {
        let current = formatTime(currentTime)
        let total = formatTime(message.duration ?? 0)
        return "\(current) / \(total)"
    }

    // MARK: - Playback

    private func togglePlayback() {
        if isPlaying {
            pausePlayback()
        } else {
            Task {
                await startPlayback()
            }
        }
    }

    private func startPlayback() async {
        // Download audio if not already downloaded
        if downloadedURL == nil {
            await downloadAudio()
        }

        guard let url = downloadedURL else {
            print("❌ No audio URL available")
            return
        }

        do {
            // Setup audio session
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)

            // Create player if needed
            if audioPlayer == nil {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
            }

            audioPlayer?.play()
            isPlaying = true

            // Start timer to update progress
            playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] _ in
                currentTime = audioPlayer?.currentTime ?? 0

                // Stop when finished
                if let player = audioPlayer, !player.isPlaying {
                    stopPlayback()
                }
            }

            print("▶️ Playing voice message")

        } catch {
            print("❌ Error playing audio: \(error.localizedDescription)")
        }
    }

    private func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
        print("⏸️ Paused voice message")
    }

    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        currentTime = 0
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    // MARK: - Download

    private func downloadAudio() async {
        guard let voiceURL = message.voiceURL else {
            print("❌ No voice URL in message")
            return
        }

        isLoading = true

        do {
            let storageRef = Storage.storage().reference().child(voiceURL)

            // Download to temporary file
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(message.id).m4a")

            _ = try await storageRef.writeAsync(toFile: tempURL)

            downloadedURL = tempURL
            print("✅ Voice memo downloaded")

        } catch {
            print("❌ Error downloading voice memo: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Helpers

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    VStack(spacing: 16) {
        // Voice message with transcription
        VoiceMessageView(
            message: Message(
                conversationId: "1",
                senderId: "user1",
                senderName: "Alice",
                type: .voice,
                voiceURL: "test.m4a",
                transcription: "Hey, can we meet tomorrow at 3pm?",
                duration: 5.5
            ),
            isFromCurrentUser: false
        )
        .background(Color.gray.opacity(0.2))
        .cornerRadius(16)

        // Voice message from current user
        VoiceMessageView(
            message: Message(
                conversationId: "1",
                senderId: "user2",
                senderName: "You",
                type: .voice,
                voiceURL: "test.m4a",
                transcription: "Sure, that works for me!",
                duration: 3.2
            ),
            isFromCurrentUser: true
        )
        .background(Color.blue)
        .cornerRadius(16)
    }
    .padding()
}
