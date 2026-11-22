import SwiftUI

@main
struct JarvisWatchApp: App {
    var body: some Scene { WindowGroup { WatchHomeView() } }
}

struct WatchHomeView: View {
    @StateObject private var bridge = WatchCommandBridge()

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform").font(.system(size: 30))
            Text("JARVIS").font(.headline)
            Button { bridge.sendQuickCommand(kind: "ask", text: "Открыть голосовой диалог") } label: {
                Label("Позвать", systemImage: "mic.fill")
            }.buttonStyle(.borderedProminent)
            Button("Новая заметка") {
                bridge.sendQuickCommand(kind: "note", text: "Заметка с Apple Watch")
            }
            Button("Напоминание") {
                bridge.sendQuickCommand(kind: "reminder", text: "Напоминание с Apple Watch")
            }
            Text(bridge.status).font(.caption2).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }.padding(.horizontal, 6)
    }
}
