import Foundation

public enum JarvisProcessingResult: Sendable, Equatable {
    case saved(list: JarvisWorkspaceList, entryID: UUID)
    case requiresAI(commandID: UUID, prompt: String)
}

public actor JarvisCommandProcessor {
    private let parser: JarvisCommandParser
    private let queue: CommandQueueStore
    private let workspace: JarvisWorkspaceStore

    public init(queue: CommandQueueStore = CommandQueueStore(),
                workspace: JarvisWorkspaceStore = JarvisWorkspaceStore(),
                parser: JarvisCommandParser = JarvisCommandParser()) {
        self.queue = queue
        self.workspace = workspace
        self.parser = parser
    }

    public func process(_ transcript: String) async throws -> JarvisProcessingResult {
        let parsed = parser.parse(transcript)
        return try await process(kind: parsed.kind, text: parsed.text)
    }

    public func process(kind: JarvisCommandKind, text: String) async throws -> JarvisProcessingResult {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw ProcessingError.emptyInput }

        let command = try await queue.enqueue(kind: kind, text: cleaned)
        guard let list = Self.destination(for: kind) else {
            return .requiresAI(commandID: command.id, prompt: command.text)
        }

        do {
            let entry = try await workspace.add(to: list, title: command.text)
            try await queue.updateStatus(id: command.id, status: .completed)
            return .saved(list: list, entryID: entry.id)
        } catch {
            try? await queue.updateStatus(id: command.id, status: .failed)
            throw error
        }
    }

    public func entries(in list: JarvisWorkspaceList? = nil) async throws -> [JarvisWorkspaceEntry] {
        try await workspace.all(in: list)
    }

    public func setCompleted(entryID: UUID, isCompleted: Bool) async throws {
        try await workspace.setCompleted(id: entryID, isCompleted: isCompleted)
    }

    public func delete(entryID: UUID) async throws {
        try await workspace.delete(id: entryID)
    }

    private static func destination(for kind: JarvisCommandKind) -> JarvisWorkspaceList? {
        switch kind {
        case .note: return .notes
        case .reminder: return .reminders
        case .addTask: return .tasks
        case .addToWatchlist: return .watchlist
        case .addToWishlist: return .wishlist
        case .ask: return nil
        }
    }

    public enum ProcessingError: Error {
        case emptyInput
    }
}
