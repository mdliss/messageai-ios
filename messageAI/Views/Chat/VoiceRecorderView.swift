//
//  VoiceRecorderView.swift
//  messageAI
//
//  Voice memo recording UI with hold-to-record interaction
//

import SwiftUI

struct VoiceRecorderView: View {
    @StateObject private var recorder = AudioRecorderService()
    @State private var audioLevel: Float = 0
    @State private var waveformTimer: Timer?

    let onSend: (URL, TimeInterval) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if recorder.isRecording {
                // Recording UI
                recordingView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                // Microphone button
                microphoneButton
            }
        }
        .onDisappear {
            waveformTimer?.invalidate()
        }
    }

    // MARK: - Microphone Button

    private var microphoneButton: some View {
        Image(systemName: "mic.fill")
            .font(.title2)
            .foregroundStyle(.blue)
            .gesture(
                LongPressGesture(minimumDuration: 0.3)
                    .onEnded { _ in
                        print("[VOICE] 🎤 Long press detected, attempting to start recording...")
                        Task {
                            let success = await recorder.startRecording()
                            if success {
                                print("[VOICE] ✅ Recording started successfully")
                                startWaveformTimer()
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            } else {
                                print("[VOICE] ❌ Failed to start recording")
                            }
                        }
                    }
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onEnded { value in
                        // Only handle drag if we completed the long press
                        guard case .second(true, let drag?) = value else {
                            print("[VOICE] ⚠️ Drag gesture ended without completing long press")
                            return
                        }

                        if recorder.isRecording {
                            print("[VOICE] 📍 Drag ended - translation: height=\(drag.translation.height), width=\(drag.translation.width)")
                            // Swipe up or left to cancel
                            if drag.translation.height < -50 || drag.translation.width < -50 {
                                print("[VOICE] 🚫 Cancelling recording (swipe detected)")
                                cancelRecording()
                            } else {
                                // Release to send
                                print("[VOICE] 📤 Sending recording (release detected)")
                                sendRecording()
                            }
                        }
                    }
            )
    }

    // MARK: - Recording View

    private var recordingView: some View {
        HStack(spacing: 16) {
            // Cancel indicator
            VStack(spacing: 4) {
                Image(systemName: "chevron.up")
                    .font(.caption)
                Text("cancel")
                    .font(.caption2)
            }
            .foregroundStyle(.red)
            .opacity(0.6)

            // Waveform visualization
            HStack(spacing: 2) {
                ForEach(0..<20, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: 3, height: CGFloat.random(in: 8...(8 + CGFloat(audioLevel * 30))))
                        .animation(.easeInOut(duration: 0.1), value: audioLevel)
                }
            }
            .frame(height: 40)

            // Duration
            Text(formatDuration(recorder.recordingDuration))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)

            Spacer()

            // Stop button
            Button {
                print("[VOICE] 🛑 Stop button tapped")
                sendRecording()
            } label: {
                Circle()
                    .fill(Color.red)
                    .frame(width: 44, height: 44)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                            .frame(width: 16, height: 16)
                    }
            }
            .scaleEffect(1.1)
            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: recorder.isRecording)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 8)
    }

    // MARK: - Actions

    private func sendRecording() {
        print("[VOICE] 🔄 sendRecording() called")
        stopWaveformTimer()

        guard let url = recorder.stopRecording() else {
            print("[VOICE] ❌ No recording URL returned from recorder.stopRecording()")
            return
        }

        let duration = recorder.recordingDuration
        print("[VOICE] ✅ Recording stopped successfully")
        print("[VOICE] 📁 Audio file URL: \(url.lastPathComponent)")
        print("[VOICE] ⏱️ Duration: \(String(format: "%.1f", duration))s")
        print("[VOICE] 📤 Calling onSend callback...")
        onSend(url, duration)
        print("[VOICE] ✅ onSend callback completed")

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func cancelRecording() {
        print("[VOICE] 🚫 cancelRecording() called")
        stopWaveformTimer()
        recorder.cancelRecording()
        onCancel()
        print("[VOICE] ✅ Recording cancelled")

        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    // MARK: - Waveform Timer

    private func startWaveformTimer() {
        waveformTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            audioLevel = recorder.getAudioLevel()
        }
    }

    private func stopWaveformTimer() {
        waveformTimer?.invalidate()
        waveformTimer = nil
        audioLevel = 0
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    VStack {
        Spacer()
        VoiceRecorderView(
            onSend: { url, duration in
                print("Send: \(url), duration: \(duration)")
            },
            onCancel: {
                print("Cancelled")
            }
        )
        .padding()
    }
}
