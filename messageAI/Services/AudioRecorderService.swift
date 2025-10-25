//
//  AudioRecorderService.swift
//  messageAI
//
//  Service for recording voice memos using AVAudioRecorder
//

import Foundation
import AVFoundation
import Combine

/// Service managing audio recording for voice memos
class AudioRecorderService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var hasPermission = false

    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var audioFileURL: URL?

    override init() {
        super.init()
        checkPermission()
    }

    // MARK: - Permission

    /// Check if microphone permission is granted
    func checkPermission() {
        let status = AVAudioSession.sharedInstance().recordPermission

        switch status {
        case .granted:
            hasPermission = true
            print("🎤 Microphone permission: GRANTED")
        case .denied:
            hasPermission = false
            print("⚠️ Microphone permission: DENIED")
        case .undetermined:
            hasPermission = false
            print("❓ Microphone permission: UNDETERMINED")
        @unknown default:
            hasPermission = false
        }
    }

    /// Request microphone permission
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.hasPermission = granted
                    print("🎤 Microphone permission request: \(granted ? "GRANTED" : "DENIED")")
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    // MARK: - Recording

    /// Start recording audio
    func startRecording() async -> Bool {
        print("[VOICE] 🎙️ startRecording() called")
        // Check permission first
        if !hasPermission {
            print("[VOICE] ⚠️ No permission yet, requesting...")
            let granted = await requestPermission()
            if !granted {
                print("[VOICE] ❌ Cannot record: permission denied")
                return false
            }
            print("[VOICE] ✅ Permission granted")
        } else {
            print("[VOICE] ✅ Permission already granted")
        }

        // Setup audio session
        let audioSession = AVAudioSession.sharedInstance()

        do {
            print("[VOICE] 🔧 Setting up audio session...")
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            print("[VOICE] ✅ Audio session configured")

            // Create temporary file for recording
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "\(UUID().uuidString).m4a"
            audioFileURL = tempDir.appendingPathComponent(fileName)

            guard let url = audioFileURL else {
                print("[VOICE] ❌ Failed to create recording URL")
                return false
            }
            print("[VOICE] 📁 Recording file path: \(url.path)")

            // Configure recording settings
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            // Create and start recorder
            print("[VOICE] 🎬 Creating AVAudioRecorder...")
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()

            let success = audioRecorder?.record() ?? false

            if success {
                await MainActor.run {
                    isRecording = true
                    recordingDuration = 0
                }
                startTimer()
                print("[VOICE] ✅ Recording started: \(url.lastPathComponent)")
            } else {
                print("[VOICE] ❌ Failed to start AVAudioRecorder")
            }

            return success

        } catch {
            print("[VOICE] ❌ Error starting recording: \(error.localizedDescription)")
            return false
        }
    }

    /// Stop recording and return the file URL
    func stopRecording() -> URL? {
        print("[VOICE] 🛑 stopRecording() called")
        audioRecorder?.stop()
        stopTimer()

        let url = audioFileURL
        let duration = recordingDuration

        Task { @MainActor in
            isRecording = false
            recordingDuration = 0
        }

        if let url = url {
            print("[VOICE] ✅ Recording stopped: \(String(format: "%.1f", duration))s")
            print("[VOICE] 📁 File saved at: \(url.path)")

            // Verify file exists
            if FileManager.default.fileExists(atPath: url.path) {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    print("[VOICE] ✅ File exists, size: \(fileSize) bytes")
                } catch {
                    print("[VOICE] ⚠️ File exists but couldn't get attributes: \(error)")
                }
            } else {
                print("[VOICE] ❌ File does NOT exist at path!")
            }
        } else {
            print("[VOICE] ❌ No URL to return (audioFileURL is nil)")
        }

        return url
    }

    /// Cancel recording and delete temporary file
    func cancelRecording() {
        audioRecorder?.stop()
        stopTimer()

        // Delete temporary file
        if let url = audioFileURL {
            try? FileManager.default.removeItem(at: url)
            print("🗑️ Recording cancelled and file deleted")
        }

        Task { @MainActor in
            isRecording = false
            recordingDuration = 0
        }

        audioFileURL = nil
    }

    // MARK: - Timer

    private func startTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.recordingDuration = self.audioRecorder?.currentTime ?? 0
            }
        }
    }

    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    /// Get current audio power level for waveform visualization
    func getAudioLevel() -> Float {
        guard let recorder = audioRecorder, recorder.isRecording else {
            return 0.0
        }

        recorder.updateMeters()
        let avgPower = recorder.averagePower(forChannel: 0)

        // Normalize to 0.0 - 1.0 range
        // avgPower ranges from -160 (silence) to 0 (max volume)
        let normalized = (avgPower + 160) / 160
        return max(0, min(1, normalized))
    }

    // MARK: - Cleanup

    deinit {
        stopTimer()
        audioRecorder?.stop()
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorderService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            print("✅ Recording finished successfully")
        } else {
            print("❌ Recording finished with error")
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("❌ Recording encoding error: \(error.localizedDescription)")
        }
    }
}
