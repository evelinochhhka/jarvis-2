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
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored.first?.id, entry.id)
        XCTAssertEqual(restored.first?.list, entry.list)
        XCTAssertEqual(restored.first?.title, entry.title)
        XCTAssertEqual(restored.first?.isCompleted, entry.isCompleted)
        XCTAssertEqual(restored.first?.reminder, entry.reminder)
        if let restoredDate = restored.first?.createdAt {
            XCTAssertLessThan(abs(restoredDate.timeIntervalSince(entry.createdAt)), 1)
        } else {
            XCTFail("Persisted entry must retain its creation date")
        }
    }

    func testReminderIsNotReportedAsScheduledWithoutDateAndTime() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let processor = JarvisCommandProcessor(
            queue: CommandQueueStore(fileURL: directory.appendingPathComponent("queue.json")),
            workspace: JarvisWorkspaceStore(fileURL: directory.appendingPathComponent("workspace.json"))
        )

        let result = try await processor.process("Напомни мне купить тетради")
        guard case let .savedReminderNeedsSchedule(entryID) = result else {
            return XCTFail("Reminder without a date must require scheduling")
        }
        let entries = try await processor.entries(in: .reminders)
        XCTAssertEqual(entries.first?.id, entryID)
        XCTAssertNil(entries.first?.reminder)
    }

    func testNaturalLanguageReminderStoresExtractedTitleAndSchedule() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let processor = JarvisCommandProcessor(
            queue: CommandQueueStore(fileURL: directory.appendingPathComponent("queue.json")),
            workspace: JarvisWorkspaceStore(fileURL: directory.appendingPathComponent("workspace.json"))
        )

        let result = try await processor.process(kind: .reminder, text: "купить тетради завтра в 18:30")
        guard case let .saved(list, entryID) = result else {
            return XCTFail("A reminder with an explicit date and time should be scheduled")
        }
        XCTAssertEqual(list, .reminders)
        let entries = try await processor.entries(in: .reminders)
        let entry = try XCTUnwrap(entries.first(where: { $0.id == entryID }))
        XCTAssertEqual(entry.title, "купить тетради")
        let schedule = try XCTUnwrap(entry.reminder)
        XCTAssertEqual(schedule.repeatFrequency, JarvisReminderRepeat.none)
        XCTAssertGreaterThan(schedule.date, .now)
    }

    func testExplicitReminderSchedulePersists() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("workspace.json")
        let store = JarvisWorkspaceStore(fileURL: url)
        let date = Date(timeIntervalSince1970: 1_900_000_000)
        let schedule = JarvisReminderSchedule(date: date, repeatFrequency: .weekly)
        let created = try await store.add(to: .reminders, title: "Тренировка", reminder: schedule)
        let reloaded = JarvisWorkspaceStore(fileURL: url)
        let entries = try await reloaded.all(in: .reminders)
        XCTAssertEqual(entries.first?.reminder, schedule)
        XCTAssertEqual(entries.first?.id, created.id)
    }
}
