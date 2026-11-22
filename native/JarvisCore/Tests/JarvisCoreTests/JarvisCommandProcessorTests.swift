import XCTest
@testable import JarvisCore

final class JarvisCommandProcessorTests: XCTestCase {
    func testRussianTaskIsSavedToTasksList() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let processor = JarvisCommandProcessor(
            queue: CommandQueueStore(fileURL: directory.appendingPathComponent("queue.json")),
            workspace: JarvisWorkspaceStore(fileURL: directory.appendingPathComponent("workspace.json"))
        )

        let result = try await processor.process("Добавь задачу подготовить проект")
        guard case let .saved(list, entryID) = result else {
            return XCTFail("Expected a saved task")
        }
        XCTAssertEqual(list, .tasks)
        let entries = try await processor.entries(in: .tasks)
        XCTAssertEqual(entries.first?.id, entryID)
        XCTAssertEqual(entries.first?.title, "подготовить проект")
    }

    func testUkrainianWatchlistCommandIsSaved() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let processor = JarvisCommandProcessor(
            queue: CommandQueueStore(fileURL: directory.appendingPathComponent("queue.json")),
            workspace: JarvisWorkspaceStore(fileURL: directory.appendingPathComponent("workspace.json"))
        )

        let result = try await processor.process("Додай у хочу подивитися Дюна")
        guard case let .saved(list, _) = result else {
            return XCTFail("Expected a saved watchlist item")
        }
        XCTAssertEqual(list, .watchlist)
    }

    func testFreeformQuestionIsLeftForAIInsteadOfPretendingItWasAnswered() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let processor = JarvisCommandProcessor(
            queue: CommandQueueStore(fileURL: directory.appendingPathComponent("queue.json")),
            workspace: JarvisWorkspaceStore(fileURL: directory.appendingPathComponent("workspace.json"))
        )

        let result = try await processor.process("Объясните, почему меняются времена года")
        guard case let .requiresAI(_, prompt) = result else {
            return XCTFail("Expected AI handoff")
        }
        XCTAssertEqual(prompt, "Объясните, почему меняются времена года")
    }

    func testWorkspacePersistsAcrossStoreInstances() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("workspace.json")
        let first = JarvisWorkspaceStore(fileURL: url)
        let entry = try await first.add(to: .wishlist, title: "Новый проект")
        let second = JarvisWorkspaceStore(fileURL: url)
        let restored = try await second.all(in: .wishlist)
        XCTAssertEqual(restored, [entry])
    }
}
