import SwiftUI

@main
struct JarvisWatchApp: App {
    var body: some Scene { WindowGroup { WatchHomeView() } }
}

struct WatchHomeView: View {
    @StateObject private var bridge = WatchCommandBridge()
    @State private var commandText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "waveform").font(.system(size: 30))
                Text("JARVIS").font(.headline)
                TextField("Продиктуйте команду", text: $commandText)
                    .textFieldStyle(.roundedBorder)
                Button {
                    let value = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !value.isEmpty else { return }
                    bridge.sendQuickCommand(kind: "ask", text: value)
                    commandText = ""
                } label: {
                    Label("Отправить", systemImage: "mic.fill")
                }.buttonStyle(.borderedProminent)
                Button("Новая заметка") {
                    bridge.sendQuickCommand(kind: "note", text: "Новая заметка")
                }
                Button("Напоминание") {
                    bridge.sendQuickCommand(kind: "reminder", text: "Новое напоминание")
                }
                Text(bridge.status).font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }.padding(.horizontal, 6)
        }
    }
}
