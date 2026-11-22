import AppIntents

struct OpenJarvisIntent: AppIntent {
    static var title: LocalizedStringResource = "Открыть JARVIS"
    static var description = IntentDescription("Запускает голосовой интерфейс JARVIS.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct JarvisAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenJarvisIntent(),
            phrases: [
                "Позови \(.applicationName)",
                "Открой \(.applicationName)"
            ],
            shortTitle: "Позвать JARVIS",
            systemImageName: "waveform"
        )
    }
}
