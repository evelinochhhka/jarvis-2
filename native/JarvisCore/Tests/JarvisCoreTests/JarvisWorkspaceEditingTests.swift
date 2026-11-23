import XCTest
@testable import JarvisCore

final class JarvisWorkspaceEditingTests: XCTestCase {
    func testUpdateChangesTitleAndReminderScheduleWithoutChangingIdentity() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("workspace.json")
        let store = JarvisWorkspaceStore(fileURL: url)
        let original = try await store.add(
            to: .reminders,
            title: "Купить тетради",
            reminder: JarvisReminderSchedule(date: Date(timeIntervalSince1970: 1_900_000_000))
        )
        let nextSchedule = JarvisReminderSchedule(
            date: Date(timeIntervalSince1970: 1_910_000_000),
            repeatFrequency: .weekly
        )

        let updated = try await store.update(
            id: original.id,
            title: "Купить новые тетради",
            reminder: nextSchedule
        )

        XCTAssertEqual(updated.id, original.id)
        XCTAssertEqual(updated.title, "Купить новые тетради")
        XCTAssertEqual(updated.reminder, nextSchedule)
        XCTAssertEqual(updated.createdAt, original.createdAt)
    }

    func testUpdateRejectsBlankTitleAndKeepsExistingEntry() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("workspace.json")
        let store = JarvisWorkspaceStore(fileURL: url)
        let original = try await store.add(to: .tasks, title: "Подготовить проект")

        do {
            _ = try await store.update(id: original.id, title: "   ", reminder: nil)
            XCTFail("Expected empty title to be rejected")
        } catch JarvisWorkspaceStore.WorkspaceError.emptyTitle {
            // Expected validation result.
        }

        let restored = try await store.all(in: .tasks)
        XCTAssertEqual(restored.first?.title, "Подготовить проект")
    }
}
