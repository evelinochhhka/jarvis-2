import XCTest
@testable import JarvisCore

final class JarvisReminderIntentParserTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private var fixedNow: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 10, minute: 0))!
    }

    func testRussianTomorrowReminderExtractsTitleAndDate() {
        let result = JarvisReminderIntentParser().parse(
            "купить тетради завтра в 18:30",
            now: fixedNow,
            calendar: calendar
        )
        XCTAssertEqual(result.title, "купить тетради")
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: result.schedule!.date)
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 11)
        XCTAssertEqual(parts.day, 24)
        XCTAssertEqual(parts.hour, 18)
        XCTAssertEqual(parts.minute, 30)
        XCTAssertEqual(result.schedule?.repeatFrequency, .none)
    }

    func testUkrainianDailyReminderExtractsRecurrence() {
        let result = JarvisReminderIntentParser().parse(
            "зателефонувати лікарю щодня о 17:45",
            now: fixedNow,
            calendar: calendar
        )
        XCTAssertEqual(result.title, "зателефонувати лікарю")
        XCTAssertEqual(result.schedule?.repeatFrequency, .daily)
        let parts = calendar.dateComponents([.day, .hour, .minute], from: result.schedule!.date)
        XCTAssertEqual(parts.day, 23)
        XCTAssertEqual(parts.hour, 17)
        XCTAssertEqual(parts.minute, 45)
    }

    func testReminderWithoutExplicitTimeIsNotScheduled() {
        let result = JarvisReminderIntentParser().parse(
            "купить тетради завтра",
            now: fixedNow,
            calendar: calendar
        )
        XCTAssertEqual(result.title, "купить тетради завтра")
        XCTAssertNil(result.schedule)
    }
}
