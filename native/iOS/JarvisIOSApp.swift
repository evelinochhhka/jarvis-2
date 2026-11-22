import SwiftUI
import UIKit

@main
struct JarvisIOSApp: App {
    @UIApplicationDelegateAdaptor(JarvisAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup { JarvisHomeView() }
    }
}

final class JarvisAppDelegate: NSObject, UIApplicationDelegate {
    private var watchReceiver: WatchCommandReceiver?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        watchReceiver = WatchCommandReceiver()
        return true
    }
}

struct JarvisHomeView: View {
    @State private var showingVoiceCapture = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Image(systemName: "waveform").font(.system(size: 54, weight: .light))
                Text("JARVIS").font(.largeTitle.weight(.semibold))
                Text("Голосовой запуск доступен по явному действию. Для запуска без открытия интерфейса используйте Siri Shortcut или App Intent.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
                Button { showingVoiceCapture = true } label: {
                    Label("Позвать JARVIS", systemImage: "mic.fill")
                        .font(.headline).frame(maxWidth: .infinity).padding()
                }.buttonStyle(.borderedProminent)
                Text("Локальная очередь команд сохраняется на устройстве. Офлайн-ИИ и фоновое wake-word пока не подключены.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding().navigationTitle("JARVIS 2")
            .sheet(isPresented: $showingVoiceCapture) { VoiceCaptureView() }
        }
    }
}
