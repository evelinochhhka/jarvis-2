import AVFoundation
import SwiftUI
import JarvisCore

struct JarvisConversationView: View {
    @AppStorage("jarvis2.currentConversationID") private var conversationIDString = ""
    @State private var history: [JarvisConversationMessage] = []
    @State private var draft = ""
    @State private var statusMessage: String?
    @State private var isSending = false
    @State private var showDeleteConfirmation = false
    @State private var synthesizer = AVSpeechSynthesizer()
    @AppStorage("jarvis2.voice.identifier") private var selectedVoiceIdentifier = ""
    private let service = JarvisConversationService()

    private var conversationID: UUID {
        UUID(uuidString: conversationIDString) ?? UUID()
    }

    var body: some View {
        VStack(spacing: 10) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(history) { message in
                            HStack {
                                if message.role == .user { Spacer(minLength: 30) }
                                Text(message.text)
                                    .padding(12)
                                    .background(message.role == .user ? Color.blue.opacity(0.16) : Color.secondary.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                if message.role != .user { Spacer(minLength: 30) }
                            }
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                }
                .onChange(of: history.count) { _ in
                    if let last = history.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }

            HStack(spacing: 8) {
                TextField("Сообщение JARVIS", text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill").font(.title2)
                }
                .disabled(isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Отправить сообщение")
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .navigationTitle("Диалог")
        .task {
            if conversationIDString.isEmpty {
                conversationIDString = UUID().uuidString
            }
            await reload()
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Новый") {
                    conversationIDString = UUID().uuidString
                    history = []
                    statusMessage = nil
                }
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Удалить текущую беседу")
            }
        }
        .onDisappear {
            synthesizer.stopSpeaking(at: .immediate)
        }
        .confirmationDialog("Удалить текущую беседу?", isPresented: $showDeleteConfirmation,
                            titleVisibility: .visible) {
            Button("Удалить беседу", role: .destructive) { deleteCurrentConversation() }
            Button("Отмена", role: .cancel) {}
        }
    }

    private func reload() async {
        do {
            history = try await service.history(conversationID: conversationID)
        } catch {
            statusMessage = "Не удалось загрузить историю диалога."
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let activeConversationID = conversationID
        draft = ""
        isSending = true
        statusMessage = nil
        Task {
            do {
                let result = try await service.send(text, conversationID: activeConversationID)
                await reload()
                switch result {
                case .reply(let replyText):
                    statusMessage = nil
                    speak(replyText)
                case .engineUnavailable:
                    statusMessage = "Сообщение сохранено. ИИ-движок ещё не подключён, поэтому ответа пока нет."
                }
            } catch {
                statusMessage = "Не удалось сохранить сообщение."
            }
            isSending = false
        }
    }

    private func speak(_ text: String) {
        guard !selectedVoiceIdentifier.isEmpty,
              let voice = AVSpeechSynthesisVoice(identifier: selectedVoiceIdentifier) else {
            return
        }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    private func deleteCurrentConversation() {
        let activeConversationID = conversationID
        Task {
            do {
                try await service.deleteConversation(id: activeConversationID)
                history = []
                conversationIDString = UUID().uuidString
                statusMessage = "Беседа удалена."
            } catch {
                statusMessage = "Не удалось удалить беседу."
            }
        }
    }
}
