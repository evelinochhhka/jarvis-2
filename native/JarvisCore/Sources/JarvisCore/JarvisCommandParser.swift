import Foundation

public struct JarvisCommandParser: Sendable {
    public init() {}

    public func parse(_ transcript: String) -> JarvisCommand {
        let cleaned = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = cleaned.lowercased()
        let rules: [(JarvisCommandKind, [String])] = [
            (.reminder, ["напомни мне", "напомни", "нагадай мені", "нагадай"]),
            (.addTask, ["добавь в хочу сделать", "добавить в хочу сделать", "добавь задачу", "создай задачу", "додай у хочу зробити", "додати у хочу зробити", "додай завдання", "створи завдання"]),
            (.addToWatchlist, ["добавь в хочу посмотреть", "добавить в хочу посмотреть", "добавь в список просмотра", "додай у хочу подивитися", "додати у хочу подивитися"]),
            (.addToWishlist, ["добавь в мои хотелки", "добавить в мои хотелки", "добавь в хотелки", "додай у мої бажання", "додати у мої бажання"]),
            (.note, ["запиши", "сохрани заметку", "сделай заметку", "занотуй", "запиши собі", "збережи нотатку"])
        ]

        for (kind, prefixes) in rules {
            for prefix in prefixes where normalized == prefix || normalized.hasPrefix(prefix + " ") || normalized.hasPrefix(prefix + ":") || normalized.hasPrefix(prefix + ",") {
                let remainder = String(cleaned.dropFirst(prefix.count))
                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ":,.-")))
                return JarvisCommand(kind: kind, text: remainder.isEmpty ? cleaned : remainder)
            }
        }

        return JarvisCommand(kind: .ask, text: cleaned)
    }
}
