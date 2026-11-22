import XCTest
@testable import JarvisCore

final class JarvisConversationServiceTests: XCTestCase {
    func testMissingEngineIsReportedAndUserMessageIsPreserved() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("history.json")
        let store = JarvisConversationStore(fileURL: url)
        let service = JarvisConversationService(store: store)
        let conversationID = UUID()

        let result = try await service.send("Объясните тему", conversationID: conversationID)
        XCTAssertEqual(result, .engineUnavailable)
        let history = try await service.history(conversationID: conversationID)
        XCTAssertEqual(history.map(\.role), [.user])
        XCTAssertEqual(history.first?.text, "Объясните тему")
    }

    func testEmptyPromptIsRejected() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("history.json")
        let service = JarvisConversationService(store: JarvisConversationStore(fileURL: url))
        do {
            _ = try await service.send(" ", conversationID: UUID())
            XCTFail("Expected empty prompt to be rejected")
        } catch {
            XCTAssertTrue(error is JarvisConversationService.ConversationServiceError)
        }
    }
}
