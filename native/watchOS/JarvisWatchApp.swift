import SwiftUI
import JarvisCore

@main
struct JarvisWatchApp: App {
    var body: some Scene { WindowGroup { WatchHomeView() } }
}

struct WatchHomeView: View {
    @StateObject private var bridge = WatchCommandBridge()
    @State private var commandText = ""
    @State private var lastQueuedMessage: String?
    private let parser = JarvisCommandParser()

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "waveform").font(.system(size: 30))
                Text("JARVIS").font(.headline)
                TextField("Продиктуйте команду", text: $commandText)
                    .textFieldStyle(.roundedBorder)
                Button {
                    sendRecognizedCommand()
                } label: {
                    Label("Отправить", systemImage: "arrow.up.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Новая заметка") {
                    commandText = "Запиши заметку: "
                    lastQueuedMessage = "Продиктуйте текст заметки и нажмите «Отправить»."
                }
                Button("Новое напоминание") {
                    commandText = "Напомни мне "
                    lastQueuedMessage = "Продиктуйте текст напоминания и нажмите «Отправить»."
                }

                if let lastQueuedMessage {
                    Text(lastQueuedMessage).font(.caption2).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Text(bridge.status).font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("Команда передаётся на iPhone. Это подтверждает доставку, но не означает, что JARVIS уже выполнил её.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }.padding(.horizontal, 6)
        }
    }

    private func sendRecognizedCommand() {
        let command = parser.parse(commandText)
        guard !command.text.isEmpty else { return }
        bridge.sendQuickCommand(kind: command.kind.rawValue, text: command.text)
        lastQueuedMessage = "Команда отправлена на iPhone: \(command.kind.rawValue)"
        commandText = ""
    }
}
