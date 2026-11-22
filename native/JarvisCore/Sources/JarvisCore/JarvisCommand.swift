import Foundation

public enum JarvisCommandKind: String, Codable, Sendable, Equatable {
    case note, reminder, addTask, addToWatchlist, addToWishlist, ask
}

public struct JarvisCommand: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let kind: JarvisCommandKind
    public let text: String
    public let createdAt: Date
    public var status: Status

    public enum Status: String, Codable, Sendable { case queued, delivered, completed, failed }

    public init(id: UUID = UUID(), kind: JarvisCommandKind, text: String,
                createdAt: Date = .now, status: Status = .queued) {
        self.id = id
        self.kind = kind
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
        self.status = status
    }
}

public struct JarvisDeviceStatus: Codable, Sendable, Equatable {
    public let deviceName: String
    public let batteryPercent: Int?
    public let capturedAt: Date
    public let isReachable: Bool

    public init(deviceName: String, batteryPercent: Int?, capturedAt: Date = .now, isReachable: Bool) {
        self.deviceName = deviceName
        self.batteryPercent = batteryPercent.map { min(100, max(0, $0)) }
        self.capturedAt = capturedAt
        self.isReachable = isReachable
    }
}
