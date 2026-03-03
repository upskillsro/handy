import Foundation

struct LocalOllamaModel: Identifiable, Equatable {
    let id: String
    let name: String
}

@MainActor
final class LocalOllamaModelStore: ObservableObject {
    @Published var models: [LocalOllamaModel] = []
    @Published var lastError: String?

    private struct TagsResponse: Decodable {
        struct ModelEntry: Decodable {
            let name: String
        }

        let models: [ModelEntry]
    }

    func load(from baseURLString: String) async {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let baseURL = URL(string: trimmed) else {
            lastError = "Invalid Ollama URL."
            models = []
            return
        }

        let tagsURL = baseURL.appendingPathComponent("api/tags")
        var request = URLRequest(url: tagsURL)
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                lastError = "Could not load local Ollama models."
                models = []
                return
            }

            let decoded = try JSONDecoder().decode(TagsResponse.self, from: data)
            let uniqueNames = Array(Set(decoded.models.map(\.name))).sorted()
            models = uniqueNames.map { LocalOllamaModel(id: $0, name: $0) }
            lastError = nil
        } catch {
            lastError = "Could not load local Ollama models."
            models = []
        }
    }
}
