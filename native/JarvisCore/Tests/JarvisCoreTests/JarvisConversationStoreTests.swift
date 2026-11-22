import XCTest
@testable import JarvisCore

final class JarvisConversationStoreTests: XCTestCase {
    func testConversationHistoryPersistsAndCanBeDeleted() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("history.json")
        let conversationID = UUID()
        let first = JarvisConversationStore(fileURL: url)
        _ = try await first.append(conversationID: conversationID, role: .user, text: "Привет")
        _ = try await first.append(conversationID: conversationID, role: .assistant, text: "Здравствуйте")

        let second = JarvisConversationStore(fileURL: url)
        let history = try await second.history(conversationID: conversationID)
        XCTAssertEqual(history.map(\.role), [.user, .assistant])
        XCTAssertEqual(history.count, 2)

        try await second.deleteConversation(id: conversationID)
        XCTAssertTrue(try await second.history(conversationID: conversationID).isEmpty)
    }

    func testEmptyMessagesAreRejected() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("history.json")
        let store = JarvisConversationStore(fileURL: url)
        do {
            _ = try await store.append(conversationID: UUID(), role: .user, text: "  ")
            XCTFail("Expected empty message to be rejected")
        } catch {
            XCTAssertTrue(error is JarvisConversationStore.ConversationError)
        }
    }
}
