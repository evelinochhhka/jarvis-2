import Foundation

public struct JarvisMemoryItem: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let key: String
    public let value: String
    public let createdAt: Date
    public let updatedAt: Date

    public init(id: UUID = UUID(), key: String, value: String,
                createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        self.value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public actor JarvisMemoryStore {
    private let fileURL: URL
    private var items: [JarvisMemoryItem] = []
    private var loaded = false

    public init(fileURL: URL? = nil) {
        if let fileURL { self.fileURL = fileURL }
        else {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.fileURL = directory.appendingPathComponent("jarvis-approved-memory.json")
        }
    }

    @discardableResult
    public func remember(key: String, value: String) throws -> JarvisMemoryItem {
        try loadIfNeeded()
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty, !cleanValue.isEmpty else { throw MemoryError.emptyField }

        if let index = items.firstIndex(where: { $0.key.caseInsensitiveCompare(cleanKey) == .orderedSame }) {
            let previous = items[index]
            let updated = JarvisMemoryItem(id: previous.id, key: cleanKey, value: cleanValue,
                                           createdAt: previous.createdAt, updatedAt: .now)
            items[index] = updated
            try persist()
            return updated
        }

        let item = JarvisMemoryItem(key: cleanKey, value: cleanValue)
        items.append(item)
        try persist()
        return item
    }

    public func all() throws -> [JarvisMemoryItem] {
        try loadIfNeeded()
        return items.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func forget(id: UUID) throws {
        try loadIfNeeded()
        guard items.contains(where: { $0.id == id }) else { throw MemoryError.itemNotFound }
        items.removeAll { $0.id == id }
        try persist()
    }

    public func forgetAll() throws {
        try loadIfNeeded()
        items.removeAll()
        try persist()
    }

    private func loadIfNeeded() throws {
        guard !loaded else { return }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            loaded = true
            return
        }
        do {
            items = try JSONDecoder.jarvisMemory.decode([JarvisMemoryItem].self,
                                                         from: Data(contentsOf: fileURL))
            loaded = true
        } catch {
            throw MemoryError.corruptStore
        }
    }

    private func persist() throws {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try JSONEncoder.jarvisMemory.encode(items).write(to: fileURL, options: .atomic)
            #if os(iOS)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: fileURL.path
            )
            #endif
        } catch {
            throw MemoryError.persistenceFailed
        }
    }

    public enum MemoryError: Error {
        case emptyField, itemNotFound, corruptStore, persistenceFailed
    }
}

private extension JSONEncoder {
    static var jarvisMemory: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var jarvisMemory: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
