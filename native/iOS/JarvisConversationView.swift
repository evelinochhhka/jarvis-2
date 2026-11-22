import SwiftUI
import JarvisCore

struct JarvisConversationView: View {
    @State private var conversationID = UUID()
    @State private var history: [JarvisConversationMessage] = []
    @State private var draft = ""
    @State private var statusMessage: String?
    @State private var isSending = false
    private let service = JarvisConversationService()

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
        .task { await reload() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Новый") {
                    conversationID = UUID()
                    history = []
                    statusMessage = nil
                }
            }
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
        draft = ""
        isSending = true
        statusMessage = nil
        Task {
            do {
                let result = try await service.send(text, conversationID: conversationID)
                await reload()
                switch result {
                case .reply:
                    statusMessage = nil
                case .engineUnavailable:
                    statusMessage = "Сообщение сохранено. ИИ-движок ещё не подключён, поэтому ответа пока нет."
                }
            } catch {
                statusMessage = "Не удалось сохранить сообщение."
            }
            isSending = false
        }
    }
}
