import Foundation

protocol TranscriptionProvider {
    func transcribe(audioFileURL: URL) async throws -> String
}
