import Foundation

struct OllamaClient {
    struct ChatMessage: Codable {
        let role: String
        let content: String
    }

    struct ChatRequest: Codable {
        let model: String
        let messages: [ChatMessage]
        let stream: Bool
        let think: Bool
        let options: [String: Double]
    }

    struct ChatResponse: Codable {
        struct ResponseMessage: Codable {
            let role: String
            let content: String
        }

        let message: ResponseMessage
    }

    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func chat(model: String, messages: [ChatMessage], timeout: TimeInterval = 20) async throws -> String {
        let endpoint = baseURL.appendingPathComponent("api/chat")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ChatRequest(model: model, messages: messages, stream: false, think: false, options: ["temperature": 0.1])
        )

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AssistantError.ollamaUnavailable
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                let responseBody = String(data: data, encoding: .utf8) ?? ""
                if responseBody.localizedCaseInsensitiveContains("not found") {
                    throw AssistantError.modelNotInstalled
                }
                throw AssistantError.ollamaUnavailable
            }

            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            return decoded.message.content
        } catch let error as AssistantError {
            throw error
        } catch {
            throw AssistantError.ollamaUnavailable
        }
    }
}
