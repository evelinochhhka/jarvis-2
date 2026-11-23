import AppIntents
import Foundation

struct OpenJarvisIntent: AppIntent {
    static var title: LocalizedStringResource = "Открыть JARVIS"
    static var description = IntentDescription("Запускает голосовой интерфейс JARVIS.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "jarvis2.openVoiceCapture")
        return .result()
    }
}

struct JarvisAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenJarvisIntent(),
            phrases: [
                "Позови \(.applicationName)",
                "Открой \(.applicationName)",
                "Поклич \(.applicationName)",
                "Відкрий \(.applicationName)"
            ],
            shortTitle: "Позвать JARVIS",
            systemImageName: "waveform"
        )
    }
}
