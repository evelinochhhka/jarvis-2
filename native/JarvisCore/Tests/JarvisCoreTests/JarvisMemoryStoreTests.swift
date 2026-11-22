import XCTest
@testable import JarvisCore

final class JarvisMemoryStoreTests: XCTestCase {
    func testMemoryCanBeAddedUpdatedAndDeleted() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("memory.json")
        let store = JarvisMemoryStore(fileURL: url)
        let first = try await store.remember(key: "preferred language", value: "Russian")
        let updated = try await store.remember(key: "Preferred Language", value: "Russian and Ukrainian")
        XCTAssertEqual(first.id, updated.id)
        XCTAssertEqual(updated.value, "Russian and Ukrainian")
        let afterUpdate = try await store.all()
        XCTAssertEqual(afterUpdate.count, 1)
        try await store.forget(id: updated.id)
        let remaining = try await store.all()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testEmptyMemoryFieldsAreRejected() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("memory.json")
        let store = JarvisMemoryStore(fileURL: url)
        do {
            _ = try await store.remember(key: " ", value: "some value")
            XCTFail("Expected empty key to be rejected")
        } catch {
            XCTAssertTrue(error is JarvisMemoryStore.MemoryError)
        }
    }
}
