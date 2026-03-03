import Foundation

struct InstalledTranscriptionModel: Identifiable, Equatable {
    let id: String
    let name: String
    let path: String
    let source: String
}

enum InstalledTranscriptionModels {
    static var recommendedDefaultModelPath: String {
        discover().first?.path ?? ""
    }

    static func discover() -> [InstalledTranscriptionModel] {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates: [(name: String, path: String, source: String)] = [
            ("Handy Whisper Turbo", "\(homeDirectory)/Library/Application Support/com.pais.handy/models/ggml-large-v3-turbo.bin", "Handy"),
            ("Handy Whisper Medium", "\(homeDirectory)/Library/Application Support/com.pais.handy/models/whisper-medium-q4_1.bin", "Handy"),
            ("Handy Whisper Small", "\(homeDirectory)/Library/Application Support/com.pais.handy/models/ggml-small.bin", "Handy"),
            ("Whispering Small EN", "\(homeDirectory)/Library/Application Support/com.bradenwong.whispering/whisper-models/ggml-small.en.bin", "Whispering"),
            ("Whispering Small EN OpenVINO", "\(homeDirectory)/Library/Application Support/com.bradenwong.whispering/whisper-models/ggml-small.en-encoder-openvino.bin", "Whispering")
        ]

        return candidates.compactMap { candidate in
            guard FileManager.default.fileExists(atPath: candidate.path) else { return nil }
            return InstalledTranscriptionModel(
                id: candidate.path,
                name: candidate.name,
                path: candidate.path,
                source: candidate.source
            )
        }
    }
}
