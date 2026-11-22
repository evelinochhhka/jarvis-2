import XCTest
@testable import JarvisCore

final class CommandQueueStoreTests: XCTestCase {
    func testQueuePersistsAndUpdatesStatus() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("queue.json")
        let store = CommandQueueStore(fileURL: url)
        let command = try await store.enqueue(kind: .note, text: "  Проверить заряд часов  ")
        XCTAssertEqual(command.text, "Проверить заряд часов")
        let pendingBefore = try await store.pending()
        XCTAssertEqual(pendingBefore.count, 1)
        try await store.updateStatus(id: command.id, status: .completed)
        let pendingAfter = try await store.pending()
        XCTAssertEqual(pendingAfter.count, 0)
        let reloaded = CommandQueueStore(fileURL: url)
        let restored = try await reloaded.all()
        XCTAssertEqual(restored.first?.status, .completed)
    }

    func testEmptyCommandIsRejected() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("queue.json")
        let store = CommandQueueStore(fileURL: url)
        do {
            _ = try await store.enqueue(kind: .note, text: "   ")
            XCTFail("Empty command should be rejected")
        } catch { XCTAssertTrue(error is CommandQueueStore.QueueError) }
    }
}
