import Foundation

struct WhisperCLITranscriptionProvider: TranscriptionProvider {
    let command: String
    let argsTemplate: String
    let modelPath: String

    func transcribe(audioFileURL: URL) async throws -> String {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else {
            throw AssistantError.transcriptionNotConfigured
        }

        let process = Process()
        let resolvedArguments = resolvedArguments(for: audioFileURL.path, modelPath: modelPath)

        if FileManager.default.isExecutableFile(atPath: trimmedCommand) {
            process.executableURL = URL(fileURLWithPath: trimmedCommand)
            process.arguments = resolvedArguments
        } else if commandLooksResolvableByPATH(trimmedCommand) {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [trimmedCommand] + resolvedArguments
        } else {
            throw AssistantError.transcriptionCommandNotFound
        }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw AssistantError.transcriptionCommandNotFound
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            throw AssistantError.transcriptionFailed(errorOutput.isEmpty ? "Transcription failed." : errorOutput)
        }

        guard !output.isEmpty else {
            throw AssistantError.transcriptionFailed("Transcription returned no text.")
        }

        return output
    }

    private func resolvedArguments(for inputPath: String, modelPath: String) -> [String] {
        let template = argsTemplate
            .replacingOccurrences(of: "{input}", with: inputPath)
            .replacingOccurrences(of: "{model}", with: modelPath)
        return template
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }
    private func commandLooksResolvableByPATH(_ command: String) -> Bool {
        !command.contains("/")
    }
}
