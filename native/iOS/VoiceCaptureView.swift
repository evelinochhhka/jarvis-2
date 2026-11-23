import SwiftUI
import Speech
import AVFoundation
import JarvisCore

private enum JarvisSpeechLanguage: String, CaseIterable, Identifiable {
    case russian = "ru-RU"
    case ukrainian = "uk-UA"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .russian: return "Русский"
        case .ukrainian: return "Українська"
        }
    }
}

struct VoiceCaptureView: View {
    @Environment(\\.dismiss) private var dismiss
    @StateObject private var recognizer = OnDeviceSpeechCapture()
    @State private var selectedLanguage: JarvisSpeechLanguage = Locale.current.language.languageCode?.identifier == "uk" ? .ukrainian : .russian
    @State private var queueMessage: String?
    @State private var queueError: String?
    @State private var isProcessing = false
    @State private var synthesizer = AVSpeechSynthesizer()
    @AppStorage("jarvis2.voiceConversationID") private var voiceConversationIDString = ""
    @AppStorage("jarvis2.voice.ru.identifier") private var selectedRussianVoiceIdentifier = ""
    @AppStorage("jarvis2.voice.uk.identifier") private var selectedUkrainianVoiceIdentifier = ""
    private let processor = JarvisCommandProcessor()
    private let reminderScheduler = JarvisReminderScheduler()

    private var conversationService: JarvisConversationService {
        JarvisConversationService(store: JarvisConversationStore(), engine: JarvisMLXAIEngine())
    }

    private var voiceConversationID: UUID {
        UUID(uuidString: voiceConversationIDString) ?? UUID()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Picker("Язык распознавания", selection: $selectedLanguage) {
                    ForEach(JarvisSpeechLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(recognizer.isListening || isProcessing)

                Image(systemName: recognizer.isListening ? "waveform.circle.fill" : "mic.circle")
                    .font(.system(size: 64))
                Text(recognizer.transcript.isEmpty ? "Нажмите кнопку и произнесите команду" : recognizer.transcript)
                    .multilineTextAlignment(.center).padding()
                Button(recognizer.isListening ? "Остановить" : recognizer.isPreparing ? "Подготовка…" : "Начать запись") {
                    recognizer.isListening ? recognizer.stop() : recognizer.start(localeIdentifier: selectedLanguage.rawValue)
                }
                .buttonStyle(.borderedProminent)
                .disabled(recognizer.isPreparing || isProcessing)

                Button(isProcessing ? "JARVIS обрабатывает…" : "Передать команду JARVIS") {
                    saveRecognizedCommand()
                }
                .buttonStyle(.bordered)
                .disabled(isProcessing || recognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let queueMessage {
                    Text(queueMessage)
                        .font(.footnote)
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let queueError {
                    Text(queueError).font(.footnote).foregroundStyle(.red)
                }
                if let error = recognizer.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
                Text("Выберите русский или украинский. Распознавание выполняется на устройстве, если iOS поддерживает офлайн-режим для выбранного языка. Команды сохраняются в списки, а вопросы передаются локальной ИИ-модели.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding().navigationTitle("Голосовой ввод")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .onAppear {
                if voiceConversationIDString.isEmpty {
                    voiceConversationIDString = UUID().uuidString
                }
                recognizer.start(localeIdentifier: selectedLanguage.rawValue)
            }
            .onDisappear {
                recognizer.stop()
                synthesizer.stopSpeaking(at: .immediate)
            }
        }
    }

    private func saveRecognizedCommand() {
        let transcript = recognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty, !isProcessing else { return }
        recognizer.stop()
        isProcessing = true
        queueError = nil

        Task {
            defer { isProcessing = false }
            do {
                let result = try await processor.process(transcript)
                switch result {
                case let .saved(list, entryID):
                    if list == .reminders {
                        let entries = try await processor.entries(in: .reminders)
                        if let entry = entries.first(where: { $0.id == entryID }) {
                            do {
                                try await reminderScheduler.schedule(entry)
                                queueMessage = "Напоминание сохранено, уведомление запланировано."
                            } catch {
                                queueMessage = "Напоминание сохранено, но уведомление не создано. Проверьте разрешения и дату."
                            }
                        } else {
                            queueMessage = "Напоминание сохранено, но его расписание не удалось проверить."
                        }
                    } else {
                        queueMessage = "Сохранено в раздел «\\(list.title)»."
                    }
                case .savedReminderNeedsSchedule:
                    queueMessage = "Напоминание сохранено без даты и времени. Добавьте дату и время, чтобы включить уведомление."
                case .requiresAI(_, let prompt):
                    await answerWithLocalAI(prompt)
                }
            } catch {
                queueError = "Не удалось обработать команду: \\(error.localizedDescription)"
                queueMessage = nil
            }
        }
    }

    private func answerWithLocalAI(_ prompt: String) async {
        queueMessage = "Локальная модель готовит ответ…"
        do {
            let result = try await conversationService.send(prompt, conversationID: voiceConversationID)
            switch result {
            case .reply(let reply):
                queueMessage = reply
                speak(reply)
            case .engineUnavailable:
                queueMessage = "Локальный ИИ недоступен. Откройте раздел локальной модели и завершите её загрузку."
            }
        } catch {
            queueError = "Ошибка локального ИИ: \\(error.localizedDescription)"
            queueMessage = nil
        }
    }

    private func speak(_ text: String) {
        let selectedIdentifier = selectedLanguage == .ukrainian
            ? selectedUkrainianVoiceIdentifier
            : selectedRussianVoiceIdentifier
        let voice = (!selectedIdentifier.isEmpty
            ? AVSpeechSynthesisVoice(identifier: selectedIdentifier)
            : nil) ?? AVSpeechSynthesisVoice(language: selectedLanguage.rawValue)

        guard let voice else {
            queueError = "Ответ готов, но голос для выбранного языка не установлен."
            return
        }

        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }
}
