import Foundation

public enum JarvisAIEngineMode: String, Sendable {
    case onDevice
    case remote
}

public protocol JarvisAIEngine: Sendable {
    var mode: JarvisAIEngineMode { get }
    func generateReply(prompt: String, history: [JarvisConversationMessage]) async throws -> String
}

public enum JarvisConversationResult: Sendable, Equatable {
    case reply(String)
    case engineUnavailable
}

public actor JarvisConversationService {
    private let store: JarvisConversationStore
    private let engine: (any JarvisAIEngine)?

    public init(store: JarvisConversationStore = JarvisConversationStore(),
                engine: (any JarvisAIEngine)? = nil) {
        self.store = store
        self.engine = engine
    }

    public func send(_ text: String, conversationID: UUID) async throws -> JarvisConversationResult {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { throw ConversationServiceError.emptyPrompt }
        _ = try await store.append(conversationID: conversationID, role: .user, text: prompt)

        guard let engine else {
            return .engineUnavailable
        }

        let storedHistory = try await store.history(conversationID: conversationID)
        let previousMessages = Array(storedHistory.dropLast())
        let response = try await engine.generateReply(prompt: prompt, history: previousMessages)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !response.isEmpty else { throw ConversationServiceError.emptyResponse }
        _ = try await store.append(conversationID: conversationID, role: .assistant, text: response)
        return .reply(response)
    }

    public func history(conversationID: UUID, limit: Int = 40) async throws -> [JarvisConversationMessage] {
        try await store.history(conversationID: conversationID, limit: limit)
    }

    public func deleteConversation(id: UUID) async throws {
        try await store.deleteConversation(id: id)
    }

    public enum ConversationServiceError: Error {
        case emptyPrompt
        case emptyResponse
    }
}
