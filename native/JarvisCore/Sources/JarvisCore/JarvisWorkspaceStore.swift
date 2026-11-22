import Foundation

public enum JarvisWorkspaceList: String, Codable, Sendable, CaseIterable, Equatable {
    case notes
    case reminders
    case tasks
    case watchlist
    case wishlist

    public var title: String {
        switch self {
        case .notes: return "Заметки"
        case .reminders: return "Напоминания"
        case .tasks: return "Хочу сделать"
        case .watchlist: return "Хочу посмотреть"
        case .wishlist: return "Мои хотелки"
        }
    }
}

public struct JarvisWorkspaceEntry: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let list: JarvisWorkspaceList
    public let title: String
    public let createdAt: Date
    public var isCompleted: Bool

    public init(id: UUID = UUID(), list: JarvisWorkspaceList, title: String,
                createdAt: Date = .now, isCompleted: Bool = false) {
        self.id = id
        self.list = list
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
        self.isCompleted = isCompleted
    }
}

public actor JarvisWorkspaceStore {
    private let fileURL: URL
    private var entries: [JarvisWorkspaceEntry] = []
    private var loaded = false

    public init(fileURL: URL? = nil) {
        if let fileURL { self.fileURL = fileURL }
        else {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.fileURL = directory.appendingPathComponent("jarvis-workspace.json")
        }
    }

    @discardableResult
    public func add(to list: JarvisWorkspaceList, title: String) throws -> JarvisWorkspaceEntry {
        try loadIfNeeded()
        let entry = JarvisWorkspaceEntry(list: list, title: title)
        guard !entry.title.isEmpty else { throw WorkspaceError.emptyTitle }
        entries.append(entry)
        try persist()
        return entry
    }

    public func all(in list: JarvisWorkspaceList? = nil) throws -> [JarvisWorkspaceEntry] {
        try loadIfNeeded()
        return entries
            .filter { list == nil || $0.list == list }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public func setCompleted(id: UUID, isCompleted: Bool) throws {
        try loadIfNeeded()
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            throw WorkspaceError.entryNotFound
        }
        entries[index].isCompleted = isCompleted
        try persist()
    }

    public func delete(id: UUID) throws {
        try loadIfNeeded()
        guard entries.contains(where: { $0.id == id }) else {
            throw WorkspaceError.entryNotFound
        }
        entries.removeAll { $0.id == id }
        try persist()
    }

    private func loadIfNeeded() throws {
        guard !loaded else { return }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            loaded = true
            return
        }
        do {
            entries = try JSONDecoder.jarvisWorkspace.decode([JarvisWorkspaceEntry].self,
                                                               from: Data(contentsOf: fileURL))
            loaded = true
        } catch {
            throw WorkspaceError.corruptStore
        }
    }

    private func persist() throws {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try JSONEncoder.jarvisWorkspace.encode(entries).write(to: fileURL, options: .atomic)
            #if os(iOS)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: fileURL.path
            )
            #endif
        } catch {
            throw WorkspaceError.persistenceFailed
        }
    }

    public enum WorkspaceError: Error {
        case emptyTitle, entryNotFound, corruptStore, persistenceFailed
    }
}

private extension JSONEncoder {
    static var jarvisWorkspace: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var jarvisWorkspace: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
