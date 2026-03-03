import Foundation

enum AssistantSettingsValidator {
    static func validateOllama(baseURL: String, model: String) -> String? {
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBaseURL.isEmpty {
            return "Ollama base URL cannot be empty."
        }
        if URL(string: trimmedBaseURL) == nil {
            return "Enter a valid Ollama base URL."
        }
        if trimmedModel.isEmpty {
            return "Ollama model cannot be empty."
        }
        return nil
    }

    static func validateTranscription(command: String, argsTemplate: String) -> String? {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCommand.isEmpty {
            return "Add a local transcription command to enable microphone input."
        }
        if !argsTemplate.isEmpty && !argsTemplate.contains("{input}") {
            return "Transcription args must include {input}."
        }
        return nil
    }
}
