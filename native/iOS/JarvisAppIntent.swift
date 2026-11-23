import AppIntents
import Foundation

/// Siri entry point for opening JARVIS directly in its voice-capture screen.
/// This shortcut is registered by iOS when the signed JARVIS app is installed.
struct OpenJarvisIntent: AppIntent {
    static var title: LocalizedStringResource = "Позвать JARVIS"
    static var description = IntentDescription(
        "Открывает JARVIS и сразу переходит к голосовому вводу."
    )
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
                "Запусти \\(.applicationName)",
                "Открой \\(.applicationName)",
                "Позови \\(.applicationName)",
                "Начни разговор с \\(.applicationName)",
                "Вызови \\(.applicationName)",
                "Поклич \\(.applicationName)",
                "Відкрий \\(.applicationName)",
                "Поклич \\(.applicationName)"
            ],
            shortTitle: "Позвать JARVIS",
            systemImageName: "waveform"
        )
    }
}
