import Foundation

public enum JarvisHTTPAIEngineError: Error, Sendable {
    case invalidServerURL
    case invalidResponse
    case serverRejected(statusCode: Int, message: String)
    case emptyReply
}

private struct JarvisChatRequest: Encodable {
    struct HistoryItem: Encodable {
        let role: String
        let content: String
    }

    let message: String
    let language: String
    let preferredLanguage: String
    let history: [HistoryItem]
}

private struct JarvisChatResponse: Decodable {
    struct Message: Decodable {
        let content: String
    }

    let message: Message
}

private struct JarvisChatErrorResponse: Decodable {
    struct Detail: Decodable {
        let message: String
    }
    let error: Detail
}

/// Connects the native app to the JARVIS server. Provider credentials stay on the server.
public final class JarvisHTTPAIEngine: JarvisAIEngine, @unchecked Sendable {
    public let mode: JarvisAIEngineMode = .remote
    private let endpoint: URL
    private let session: URLSession
    private let accessToken: String

    public init?(serverBaseURL: URL, accessToken: String = "", session: URLSession = .shared) {
        guard var components = URLComponents(url: serverBaseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let scheme = components.scheme?.lowercased() ?? ""
        let host = components.host?.lowercased() ?? ""
        let isSecure = scheme == "https"
        let isLocalDevelopment = scheme == "http" && (host == "localhost" || host == "127.0.0.1")
        guard isSecure || isLocalDevelopment else { return nil }
        let prefix = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = prefix + "/api/v1/chat"
        components.query = nil
        components.fragment = nil
        guard let endpoint = components.url else { return nil }
        self.endpoint = endpoint
        self.accessToken = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        self.session = session
    }

    public func generateReply(prompt: String, history: [JarvisConversationMessage]) async throws -> String {
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPrompt.isEmpty else { throw JarvisHTTPAIEngineError.emptyReply }

        let preferredLanguage = cleanPrompt.range(of: "[іїєґІЇЄҐ]", options: .regularExpression) != nil ? "uk" : "ru"
        let context = history.suffix(20).compactMap { item -> JarvisChatRequest.HistoryItem? in
            guard item.role == .user || item.role == .assistant else { return nil }
            return JarvisChatRequest.HistoryItem(role: item.role.rawValue, content: item.text)
        }
        let payload = JarvisChatRequest(
            message: cleanPrompt,
            language: "auto",
            preferredLanguage: preferredLanguage,
            history: context
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !accessToken.isEmpty {
            request.setValue("Bearer \\(accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw JarvisHTTPAIEngineError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(JarvisChatErrorResponse.self, from: data).error.message)
                ?? "Сервер JARVIS отклонил запрос."
            throw JarvisHTTPAIEngineError.serverRejected(statusCode: http.statusCode, message: message)
        }

        guard let reply = try? JSONDecoder().decode(JarvisChatResponse.self, from: data).message.content
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !reply.isEmpty else {
            throw JarvisHTTPAIEngineError.emptyReply
        }
        return reply
    }
}
