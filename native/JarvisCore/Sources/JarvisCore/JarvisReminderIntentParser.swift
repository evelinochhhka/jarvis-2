import Foundation

public struct JarvisReminderIntentParser: Sendable {
    public init() {}

    public func parse(_ input: String, now: Date = .now,
                      calendar suppliedCalendar: Calendar = .current) -> (title: String, schedule: JarvisReminderSchedule?) {
        var title = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = title.lowercased()
        var calendar = suppliedCalendar
        calendar.locale = Locale(identifier: normalized.range(of: "[ієїґ]", options: .regularExpression) != nil ? "uk_UA" : "ru_RU")

        let repeatFrequency: JarvisReminderRepeat
        if containsAny(normalized, ["каждый день", "ежедневно", "щодня", "кожного дня"]) {
            repeatFrequency = .daily
        } else if containsAny(normalized, ["каждую неделю", "еженедельно", "щотижня", "кожного тижня"]) {
            repeatFrequency = .weekly
        } else if containsAny(normalized, ["каждый месяц", "ежемесячно", "щомісяця", "кожного місяця"]) {
            repeatFrequency = .monthly
        } else {
            repeatFrequency = .none
        }

        let timePattern = "(?:\\bв\\s*|\\bо\\s*|\\bat\\s*)([01]?\\d|2[0-3]):([0-5]\\d)"
        guard let timeMatch = firstMatch(timePattern, in: title),
              let hourRange = Range(timeMatch.range(at: 1), in: title),
              let minuteRange = Range(timeMatch.range(at: 2), in: title),
              let hour = Int(title[hourRange]),
              let minute = Int(title[minuteRange]) else {
            return (title, nil)
        }

        let isoPattern = "\\b(20\\d{2}-\\d{2}-\\d{2})\\b"
        let baseDate: Date?
        if let dateMatch = firstMatch(isoPattern, in: title),
           let dateRange = Range(dateMatch.range(at: 1), in: title) {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = "yyyy-MM-dd"
            baseDate = formatter.date(from: String(title[dateRange]))
        } else if containsAny(normalized, ["завтра", "tomorrow"]) {
            baseDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        } else if containsAny(normalized, ["сегодня", "сьогодні", "today"]) {
            baseDate = calendar.startOfDay(for: now)
        } else {
            baseDate = calendar.startOfDay(for: now)
        }

        guard let baseDate else { return (title, nil) }
        var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = hour
        components.minute = minute
        components.second = 0
        guard var scheduledDate = calendar.date(from: components) else { return (title, nil) }

        if repeatFrequency == .none && scheduledDate <= now && !containsAny(normalized, ["сегодня", "сьогодні", "today"]) {
            scheduledDate = calendar.date(byAdding: .day, value: 1, to: scheduledDate) ?? scheduledDate
        }

        let patternsToRemove = [
            timePattern,
            isoPattern,
            "\\b(?:сегодня|сьогодні|today|завтра|tomorrow)\\b",
            "\\b(?:каждый день|ежедневно|щодня|кожного дня|каждую неделю|еженедельно|щотижня|кожного тижня|каждый месяц|ежемесячно|щомісяця|кожного місяця)\\b"
        ]
        for pattern in patternsToRemove {
            title = replacing(pattern, in: title, with: "")
        }
        title = title
            .replacingOccurrences(of: "[[:space:]]{2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: " ,;:.-")))
        guard !title.isEmpty else { return (input, nil) }

        return (title, JarvisReminderSchedule(date: scheduledDate, repeatFrequency: repeatFrequency))
    }

    private func containsAny(_ text: String, _ values: [String]) -> Bool {
        values.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private func firstMatch(_ pattern: String, in text: String) -> NSTextCheckingResult? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        return expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
    }

    private func replacing(_ pattern: String, in text: String, with replacement: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return text }
        return expression.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: replacement)
    }
}
