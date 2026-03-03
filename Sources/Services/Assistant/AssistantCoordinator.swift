import EventKit
import Foundation
import SwiftUI

@MainActor
final class AssistantCoordinator: ObservableObject {
    @Published var state: AssistantState = .idle
    @Published var inputText = ""
    @Published var recordingDuration: TimeInterval = 0
    @Published var lastTranscript = ""
    @Published var lastErrorDescription: String?
    @Published var isPanelPresented: Bool = false {
        didSet {
            if !isPanelPresented {
                dismissPanel()
            }
        }
    }

    private let settings = SettingsStore()
    private let audioRecordingService = AudioRecordingService()
    private var recordingTimer: Timer?
    private var currentAudioFileURL: URL?

    weak var remindersService: RemindersService?

    var isBusy: Bool {
        switch state {
        case .transcribing, .generating:
            return true
        default:
            return false
        }
    }

    func togglePanel() {
        isPanelPresented.toggle()
    }

    func dismissPanel() {
        if case .recording = state {
            cancelRecording()
        }
        if case .transcribing(let url) = state {
            try? FileManager.default.removeItem(at: url)
        }
        stopRecordingTimer()
        state = .idle
        lastErrorDescription = nil
        lastTranscript = ""
        inputText = ""
    }

    func submitTypedInput() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            await generateActions(from: trimmed)
        }
    }

    func beginRecording() {
        Task {
            let validationError = AssistantSettingsValidator.validateTranscription(
                command: settings.assistantTranscriptionCommand,
                argsTemplate: settings.assistantTranscriptionArgs
            )
            if validationError != nil, settings.assistantTranscriptionCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                setError(.transcriptionNotConfigured)
                return
            }

            let hasPermission = await audioRecordingService.requestPermission()
            guard hasPermission else {
                setError(.microphonePermissionDenied)
                return
            }

            do {
                currentAudioFileURL = try audioRecordingService.startRecording()
                recordingDuration = 0
                state = .recording
                startRecordingTimer()
                AppLogger.assistant.info("Assistant recording started.")
            } catch let error as AssistantError {
                setError(error)
            } catch {
                setError(.recordingFailed("Helpy could not start recording."))
            }
        }
    }

    func stopRecordingAndTranscribe() {
        Task {
            stopRecordingTimer()
            do {
                let audioURL = try audioRecordingService.stopRecording()
                currentAudioFileURL = audioURL
                state = .transcribing(audioFileURL: audioURL)
                AppLogger.transcription.info("Assistant transcription started.")

                let provider = WhisperCLITranscriptionProvider(
                    command: settings.assistantTranscriptionCommand,
                    argsTemplate: settings.assistantTranscriptionArgs,
                    modelPath: settings.assistantTranscriptionModelPath
                )
                let transcript = try await provider.transcribe(audioFileURL: audioURL)
                try? FileManager.default.removeItem(at: audioURL)
                currentAudioFileURL = nil
                lastTranscript = transcript
                inputText = transcript
                await generateActions(from: transcript)
            } catch let error as AssistantError {
                cleanupRecordingArtifacts()
                setError(error)
            } catch {
                cleanupRecordingArtifacts()
                setError(.transcriptionFailed("Helpy could not transcribe the recording."))
            }
        }
    }

    func cancelRecording() {
        audioRecordingService.cancelRecording()
        cleanupRecordingArtifacts()
        state = .idle
    }

    func retryLastInput() {
        let sourceText: String
        switch state {
        case .review(let batch):
            sourceText = batch.sourceText
        default:
            sourceText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !sourceText.isEmpty else {
            lastErrorDescription = nil
            state = .idle
            return
        }
        Task {
            await generateActions(from: sourceText)
        }
    }

    func updateAction(_ action: AssistantActionDraft) {
        guard case .review(var batch) = state,
              let index = batch.actions.firstIndex(where: { $0.id == action.id }) else { return }
        batch.actions[index] = action
        state = .review(batch)
    }

    func discardAction(_ action: AssistantActionDraft) {
        guard case .review(var batch) = state else { return }
        batch.actions.removeAll { $0.id == action.id }
        state = batch.actions.isEmpty ? .idle : .review(batch)
    }

    func discardAllActions() {
        state = .idle
    }

    func applyAction(_ action: AssistantActionDraft) {
        guard let remindersService else { return }
        do {
            try remindersService.applyAssistantAction(action, in: activeCalendar())
            discardAction(action)
        } catch let error as AssistantError {
            setError(error)
        } catch {
            setError(.invalidModelResponse)
        }
    }

    func applyAllActions() {
        guard case .review(let batch) = state, let remindersService else { return }
        do {
            for action in batch.actions {
                try remindersService.applyAssistantAction(action, in: activeCalendar())
            }
            state = .idle
            inputText = ""
            lastTranscript = ""
        } catch let error as AssistantError {
            setError(error)
        } catch {
            setError(.invalidModelResponse)
        }
    }

    func testOllamaConnection() async -> String {
        if let validation = AssistantSettingsValidator.validateOllama(
            baseURL: settings.assistantOllamaBaseURL,
            model: settings.assistantOllamaModel
        ) {
            return validation
        }

        do {
            let client = try makeOllamaClient()
            let reply = try await client.chat(
                model: settings.assistantOllamaModel,
                messages: [.init(role: "user", content: "Reply with only ok.")],
                timeout: 10
            )
            return reply.lowercased().contains("ok") ? "Ollama is reachable." : "Ollama responded successfully."
        } catch let error as AssistantError {
            return error.localizedDescription
        } catch {
            return "Ollama test failed."
        }
    }

    func testTranscriptionSetup() async -> String {
        if let validation = AssistantSettingsValidator.validateTranscription(
            command: settings.assistantTranscriptionCommand,
            argsTemplate: settings.assistantTranscriptionArgs
        ) {
            return validation
        }

        let provider = WhisperCLITranscriptionProvider(
            command: settings.assistantTranscriptionCommand,
            argsTemplate: settings.assistantTranscriptionArgs,
            modelPath: settings.assistantTranscriptionModelPath
        )

        do {
            _ = try await provider.transcribe(audioFileURL: URL(fileURLWithPath: "/tmp/nonexistent-audio.m4a"))
            return "Transcription command launched successfully."
        } catch AssistantError.transcriptionFailed {
            return "Transcription command launched. Audio-specific validation will happen on real recordings."
        } catch let error as AssistantError {
            return error.localizedDescription
        } catch {
            return "Transcription test failed."
        }
    }

    private func generateActions(from sourceText: String) async {
        let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            state = .generating(transcript: trimmed)
            lastErrorDescription = nil
            let parser = try makeTaskParser()
            let reminders = remindersService?.buildAssistantContext() ?? []
            let batch = try await parser.parseActions(from: trimmed, reminders: reminders)
            inputText = trimmed
            state = .review(batch)
            AppLogger.assistant.info("Assistant generated \(batch.actions.count, privacy: .public) action(s).")
        } catch let error as AssistantError {
            setError(error)
        } catch {
            setError(.invalidModelResponse)
        }
    }

    private func makeTaskParser() throws -> OllamaTaskParser {
        if let validation = AssistantSettingsValidator.validateOllama(
            baseURL: settings.assistantOllamaBaseURL,
            model: settings.assistantOllamaModel
        ) {
            AppLogger.ollama.error("Invalid Ollama settings: \(validation, privacy: .public)")
            throw AssistantError.ollamaUnavailable
        }

        return try OllamaTaskParser(
            client: makeOllamaClient(),
            model: settings.assistantOllamaModel,
            maxDrafts: max(settings.assistantMaxDrafts, 1)
        )
    }

    private func makeOllamaClient() throws -> OllamaClient {
        guard let url = URL(string: settings.assistantOllamaBaseURL) else {
            throw AssistantError.ollamaUnavailable
        }
        return OllamaClient(baseURL: url)
    }

    private func activeCalendar() -> EKCalendar? {
        guard let remindersService,
              let activeListId = remindersService.activeListId else { return nil }
        return remindersService.lists.first { $0.calendarIdentifier == activeListId }
    }

    private func setError(_ error: AssistantError) {
        AppLogger.assistant.error("Assistant error: \(error.localizedDescription, privacy: .public)")
        lastErrorDescription = error.localizedDescription
        state = .error(error)
    }

    private func cleanupRecordingArtifacts() {
        stopRecordingTimer()
        if let currentAudioFileURL {
            try? FileManager.default.removeItem(at: currentAudioFileURL)
        }
        currentAudioFileURL = nil
    }

    private func startRecordingTimer() {
        stopRecordingTimer()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.recordingDuration += 1
                if self.recordingDuration >= 60 {
                    self.stopRecordingAndTranscribe()
                }
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
}
