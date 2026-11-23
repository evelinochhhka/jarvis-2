import Foundation
import HuggingFace
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

private let jarvisModelConfiguration = LLMRegistry.gemma3_1B_qat_4bit

@MainActor
final class JarvisMLXModelLoader: ObservableObject {
    static let shared = JarvisMLXModelLoader()

    private enum State {
        case idle
        case loading(Task<ModelContainer, Error>)
        case loaded(ModelContainer)
    }

    @Published private(set) var progress = 0.0
    @Published private(set) var isLoading = false
    private var state = State.idle

    private init() {}

    var isLoaded: Bool {
        if case .loaded = state { return true }
        return false
    }

    func model() async throws -> ModelContainer {
        switch state {
        case .loaded(let model):
            return model
        case .loading(let task):
            return try await task.value
        case .idle:
            isLoading = true
            progress = 0
            let task = Task { [weak self] in
                try await #huggingFaceLoadModelContainer(
                    configuration: jarvisModelConfiguration
                ) { value in
                    Task { @MainActor in
                        self?.progress = value.fractionCompleted
                    }
                }
            }
            state = .loading(task)
            do {
                let model = try await task.value
                state = .loaded(model)
                progress = 1
                isLoading = false
                return model
            } catch {
                state = .idle
                isLoading = false
                throw error
            }
        }
    }
}

final class JarvisMLXAIEngine: JarvisAIEngine, @unchecked Sendable {
    private let loader: JarvisMLXModelLoader

    @MainActor
    init(loader: JarvisMLXModelLoader = .shared) {
        self.loader = loader
    }

    var mode: JarvisAIEngineMode { .onDevice }

    func generateReply(prompt: String, history: [JarvisConversationMessage]) async throws -> String {
        let model = try await loader.model()
        let session = ChatSession(
            model,
            instructions: """
            Вы локальный ИИ-помощник JARVIS. Общайтесь естественно и по делу.
            Отвечайте на русском или украинском языке в соответствии с языком пользователя.
            Учитывайте историю беседы. Не утверждайте, что выполнили действие, если оно не было реально выполнено.
            Если вопрос неоднозначен, задайте один короткий уточняющий вопрос.
            """,
            generateParameters: GenerateParameters(temperature: 0.35)
        )

        let earlierMessages = history
            .filter { $0.role == .user || $0.role == .assistant }
            .map { message in
                message.role == .user
                    ? "Пользователь: \(message.text)"
                    : "JARVIS: \(message.text)"
            }
            .joined(separator: "\n")

        let fullPrompt = earlierMessages.isEmpty
            ? prompt
            : "\(earlierMessages)\nПользователь: \(prompt)\nJARVIS:"

        var response = ""
        for try await fragment in session.streamResponse(to: fullPrompt) {
            response += fragment
        }

        let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw JarvisLocalAIError.emptyResponse
        }
        return cleaned
    }
}

enum JarvisLocalAIError: LocalizedError {
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "Локальная модель не вернула текст."
        }
    }
}
