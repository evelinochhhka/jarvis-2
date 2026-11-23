import XCTest
@testable import JarvisCore

final class JarvisCommandParserTests: XCTestCase {
    private let parser = JarvisCommandParser()

    func testRussianReminder() {
        let command = parser.parse("Напомни мне завтра проверить расписание")
        XCTAssertEqual(command.kind, .reminder)
        XCTAssertEqual(command.text, "завтра проверить расписание")
    }

    func testUkrainianTask() {
        let command = parser.parse("Додай завдання підготувати презентацію")
        XCTAssertEqual(command.kind, .addTask)
        XCTAssertEqual(command.text, "підготувати презентацію")
    }

    func testWatchlistItem() {
        let command = parser.parse("Добавь в хочу посмотреть Интерстеллар")
        XCTAssertEqual(command.kind, .addToWatchlist)
        XCTAssertEqual(command.text, "Интерстеллар")
    }

    func testUnknownPhraseRemainsQuestion() {
        let command = parser.parse("Почему небо меняет цвет?")
        XCTAssertEqual(command.kind, .ask)
        XCTAssertEqual(command.text, "Почему небо меняет цвет?")
    }

    func testEmptyInputIsNotSilentlyAcceptedAsAction() {
        let command = parser.parse("   ")
        XCTAssertEqual(command.kind, .ask)
        XCTAssertEqual(command.text, "")
    }
}
