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
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recognizer = OnDeviceSpeechCapture()
    @State private var selectedLanguage: JarvisSpeechLanguage = Locale.current.language.languageCode?.identifier == "uk" ? .ukrainian : .russian
    @State private var queueMessage: String?
    @State private var queueError: String?
    private let processor = JarvisCommandProcessor()

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Picker("Язык распознавания", selection: $selectedLanguage) {
                    ForEach(JarvisSpeechLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(recognizer.isListening)

                Image(systemName: recognizer.isListening ? "waveform.circle.fill" : "mic.circle")
                    .font(.system(size: 64))
                Text(recognizer.transcript.isEmpty ? "Нажмите кнопку и произнесите команду" : recognizer.transcript)
                    .multilineTextAlignment(.center).padding()
                Button(recognizer.isListening ? "Остановить" : "Начать запись") {
                    recognizer.isListening ? recognizer.stop() : recognizer.start(localeIdentifier: selectedLanguage.rawValue)
                }.buttonStyle(.borderedProminent)

                Button("Передать команду JARVIS") {
                    saveRecognizedCommand()
                }
                .buttonStyle(.bordered)
                .disabled(recognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let queueMessage {
                    Text(queueMessage).font(.footnote).foregroundStyle(.green)
                }
                if let queueError {
                    Text(queueError).font(.footnote).foregroundStyle(.red)
                }
                if let error = recognizer.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
                Text("Выберите русский или украинский. Если iOS поддерживает офлайн-распознавание, команда обрабатывается локально: записи добавляются в списки, а вопросы передаются будущему ИИ-модулю.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding().navigationTitle("Голосовой ввод")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Закрыть") { dismiss() } } }
        }
    }

    private func saveRecognizedCommand() {
        Task {
            do {
                let result = try await processor.process(recognizer.transcript)
                switch result {
                case let .saved(list, _):
                    queueMessage = "Сохранено в раздел «\\(list.title)»."
                case .requiresAI:
                    queueMessage = "Запрос сохранён. Для ответа требуется подключить ИИ-модель."
                }
                queueError = nil
            } catch {
                queueError = "Не удалось обработать команду. Проверьте текст и повторите."
                queueMessage = nil
            }
        }
    }
