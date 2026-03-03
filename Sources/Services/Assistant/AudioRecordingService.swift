import AVFoundation
import Foundation

final class AudioRecordingService: NSObject {
    private var recorder: AVAudioRecorder?
    private var currentFileURL: URL?

    func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }

    func startRecording() throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("helpy-assistant-\(UUID().uuidString)")
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            recorder = try AVAudioRecorder(url: outputURL, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.record(forDuration: 60)
            currentFileURL = outputURL
            return outputURL
        } catch {
            throw AssistantError.recordingFailed("Helpy could not start recording.")
        }
    }

    func stopRecording() throws -> URL {
        guard let recorder, let currentFileURL else {
            throw AssistantError.recordingFailed("There is no active recording to stop.")
        }
        recorder.stop()
        self.recorder = nil
        self.currentFileURL = nil
        return currentFileURL
    }

    func cancelRecording() {
        recorder?.stop()
        recorder = nil

        if let currentFileURL {
            try? FileManager.default.removeItem(at: currentFileURL)
        }

        self.currentFileURL = nil
    }
}
