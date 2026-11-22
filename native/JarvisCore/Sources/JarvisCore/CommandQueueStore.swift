import Foundation

public actor CommandQueueStore {
    private let fileURL: URL
    private var commands: [JarvisCommand] = []
    private var loaded = false

    public init(fileURL: URL? = nil) {
        if let fileURL { self.fileURL = fileURL }
        else {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.fileURL = directory.appendingPathComponent("jarvis-command-queue.json")
        }
    }

    public func all() throws -> [JarvisCommand] {
        try loadIfNeeded()
        return commands.sorted { $0.createdAt < $1.createdAt }
    }

    @discardableResult
    public func enqueue(kind: JarvisCommandKind, text: String) throws -> JarvisCommand {
        try loadIfNeeded()
        let command = JarvisCommand(kind: kind, text: text)
        guard !command.text.isEmpty else { throw QueueError.emptyCommand }
        commands.append(command)
        try persist()
        return command
    }

    public func updateStatus(id: UUID, status: JarvisCommand.Status) throws {
        try loadIfNeeded()
        guard let index = commands.firstIndex(where: { $0.id == id }) else {
            throw QueueError.commandNotFound
        }
        commands[index].status = status
        try persist()
    }

    public func pending() throws -> [JarvisCommand] {
        try all().filter { $0.status == .queued || $0.status == .delivered }
    }

    private func loadIfNeeded() throws {
        guard !loaded else { return }
        loaded = true
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            commands = try JSONDecoder.jarvis.decode([JarvisCommand].self, from: Data(contentsOf: fileURL))
        } catch { throw QueueError.corruptStore }
    }

    private func persist() throws {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try JSONEncoder.jarvis.encode(commands).write(to: fileURL, options: .atomic)
        } catch { throw QueueError.persistenceFailed }
    }

    public enum QueueError: Error { case emptyCommand, commandNotFound, corruptStore, persistenceFailed }
}

private extension JSONEncoder {
    static var jarvis: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
private extension JSONDecoder {
    static var jarvis: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
