import Foundation

public enum JarvisMessageRole: String, Codable, Sendable, Equatable {
    case user
    case assistant
    case system
}

public struct JarvisConversationMessage: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let conversationID: UUID
    public let role: JarvisMessageRole
    public let text: String
    public let createdAt: Date

    public init(id: UUID = UUID(), conversationID: UUID, role: JarvisMessageRole,
                text: String, createdAt: Date = .now) {
        self.id = id
        self.conversationID = conversationID
        self.role = role
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
    }
}

public actor JarvisConversationStore {
    private let fileURL: URL
    private var messages: [JarvisConversationMessage] = []
    private var loaded = false

    public init(fileURL: URL? = nil) {
        if let fileURL { self.fileURL = fileURL }
        else {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.fileURL = directory.appendingPathComponent("jarvis-conversations.json")
        }
    }

    @discardableResult
    public func append(conversationID: UUID, role: JarvisMessageRole,
                       text: String) throws -> JarvisConversationMessage {
        try loadIfNeeded()
        let message = JarvisConversationMessage(conversationID: conversationID, role: role, text: text)
        guard !message.text.isEmpty else { throw ConversationError.emptyMessage }
        messages.append(message)
        try persist()
        return message
    }

    public func history(conversationID: UUID, limit: Int = 40) throws -> [JarvisConversationMessage] {
        try loadIfNeeded()
        let safeLimit = min(200, max(1, limit))
        return Array(messages
            .filter { $0.conversationID == conversationID }
            .sorted { $0.createdAt < $1.createdAt }
            .suffix(safeLimit))
    }

    public func conversationIDs() throws -> [UUID] {
        try loadIfNeeded()
        var seen = Set<UUID>()
        return messages.sorted { $0.createdAt > $1.createdAt }.compactMap {
            seen.insert($0.conversationID).inserted ? $0.conversationID : nil
        }
    }

    public func deleteConversation(id: UUID) throws {
        try loadIfNeeded()
        messages.removeAll { $0.conversationID == id }
        try persist()
    }

    public func deleteAll() throws {
        try loadIfNeeded()
        messages.removeAll()
        try persist()
    }

    private func loadIfNeeded() throws {
        guard !loaded else { return }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            loaded = true
            return
        }
        do {
            messages = try JSONDecoder.jarvisConversation.decode(
                [JarvisConversationMessage].self, from: Data(contentsOf: fileURL)
            )
            loaded = true
        } catch {
            throw ConversationError.corruptStore
        }
    }

    private func persist() throws {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try JSONEncoder.jarvisConversation.encode(messages).write(to: fileURL, options: .atomic)
            #if os(iOS) || os(watchOS)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: fileURL.path
            )
            #endif
        } catch {
            throw ConversationError.persistenceFailed
        }
    }

    public enum ConversationError: Error {
        case emptyMessage, corruptStore, persistenceFailed
    }
}

private extension JSONEncoder {
    static var jarvisConversation: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var jarvisConversation: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
