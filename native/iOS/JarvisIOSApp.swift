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
    @AppStorage("jarvis2.openVoiceCapture") private var openVoiceCapture = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Image(systemName: "waveform").font(.system(size: 54, weight: .light))
                Text("JARVIS").font(.largeTitle.weight(.semibold))
                Text("Голосовой запуск доступен через Siri Shortcut или явное действие. iOS не разрешает стороннему приложению постоянно слушать кодовую фразу после закрытия.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)

                NavigationLink {
                    JarvisConversationView()
                } label: {
                    Label("Диалог", systemImage: "message")
                        .frame(maxWidth: .infinity).padding()
                }
                .buttonStyle(.bordered)

                Button { showingVoiceCapture = true } label: {
                    Label("Позвать JARVIS", systemImage: "mic.fill")
                        .font(.headline).frame(maxWidth: .infinity).padding()
                }
                .buttonStyle(.borderedProminent)

                NavigationLink {
                    JarvisWorkspaceView()
                } label: {
                    Label("Мои списки", systemImage: "list.bullet.rectangle")
                        .frame(maxWidth: .infinity).padding()
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    JarvisFilesView()
                } label: {
                    Label("Файлы", systemImage: "folder")
                        .frame(maxWidth: .infinity).padding()
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    JarvisMemoryView()
                } label: {
                    Label("Память", systemImage: "brain.head.profile")
                        .frame(maxWidth: .infinity).padding()
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    JarvisFocusShortcutsView()
                } label: {
                    Label("Фокусирование", systemImage: "moon.zzz")
                        .frame(maxWidth: .infinity).padding()
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    JarvisAISettingsView()
                } label: {
                    Label("Подключение ИИ", systemImage: "brain")
                        .frame(maxWidth: .infinity).padding()
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    JarvisVoiceSettingsView()
                } label: {
                    Label("Голос JARVIS", systemImage: "waveform")
                        .frame(maxWidth: .infinity).padding()
                }
                .buttonStyle(.bordered)

                Text("Локальные списки, память и файлы работают без сети. Полноценный офлайн-ИИ пока не подключён.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle("JARVIS 2")
            .sheet(isPresented: $showingVoiceCapture) { VoiceCaptureView() }
            .onAppear { consumeVoiceRequest() }
            .onChange(of: openVoiceCapture) { requested in
                if requested { consumeVoiceRequest() }
            }
        }
    }

    private func consumeVoiceRequest() {
        guard openVoiceCapture else { return }
        openVoiceCapture = false
        showingVoiceCapture = true
    }
}
