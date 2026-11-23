import AVFoundation
import SwiftUI

private struct JarvisVoiceOption: Identifiable {
    let voice: AVSpeechSynthesisVoice
    var id: String { voice.identifier }

    var languageTitle: String {
        voice.language.hasPrefix("uk") ? "Українська" : "Русский"
    }

    var qualityTitle: String {
        switch voice.quality {
        case .premium: return "Премиум"
        case .enhanced: return "Улучшенный"
        default: return "Стандартный"
        }
    }
}

struct JarvisVoiceSettingsView: View {
    @AppStorage("jarvis2.voice.ru.identifier") private var selectedRussianVoiceIdentifier = ""
    @AppStorage("jarvis2.voice.uk.identifier") private var selectedUkrainianVoiceIdentifier = ""
    @AppStorage("jarvis2.voice.identifier") private var legacyVoiceIdentifier = ""
    @State private var voices: [JarvisVoiceOption] = []
    @State private var synthesizer = AVSpeechSynthesizer()
    @State private var statusMessage = "Список будет получен непосредственно с этого устройства."

    private var russianVoices: [JarvisVoiceOption] {
        voices.filter { $0.voice.language.hasPrefix("ru") }
    }

    private var ukrainianVoices: [JarvisVoiceOption] {
        voices.filter { $0.voice.language.hasPrefix("uk") }
    }

    var body: some View {
        List {
            Section {
                Text("Это голоса, уже доступные системному синтезатору iOS. Состав и качество зависят от загруженных голосовых пакетов на iPhone или iPad.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            voiceSection(title: "Русские голоса", options: russianVoices)
            voiceSection(title: "Українські голоси", options: ukrainianVoices)

            Section {
                Button {
                    synthesizer.stopSpeaking(at: .immediate)
                    statusMessage = "Воспроизведение остановлено."
                } label: {
                    Label("Остановить образец", systemImage: "stop.fill")
                }
                .disabled(!synthesizer.isSpeaking)

                Button("Обновить список голосов") {
                    loadVoices()
                }
            }
        }
        .navigationTitle("Голос JARVIS")
        .onAppear {
            migrateLegacyVoiceSelection()
            loadVoices()
        }
        .onDisappear {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    @ViewBuilder
    private func voiceSection(title: String, options: [JarvisVoiceOption]) -> some View {
        Section(title) {
            if options.isEmpty {
                Text("На устройстве не найден установленный голос для этого языка.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(options) { option in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(option.voice.name)
                                    .font(.body.weight(.medium))
                                Text("\(option.qualityTitle) · \(option.voice.language)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedIdentifier(for: option) == option.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        HStack {
                            Button("Выбрать") {
                                if option.voice.language.hasPrefix("uk") {
                                    selectedUkrainianVoiceIdentifier = option.id
                                } else {
                                    selectedRussianVoiceIdentifier = option.id
                                }
                                statusMessage = "Выбран голос «\(option.voice.name)» для языка: \(option.languageTitle)."
                            }
                            .buttonStyle(.bordered)
                            Spacer()
                            Button {
                                preview(option)
                            } label: {
                                Label("Прослушать", systemImage: "play.fill")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func selectedIdentifier(for option: JarvisVoiceOption) -> String {
        option.voice.language.hasPrefix("uk")
            ? selectedUkrainianVoiceIdentifier
            : selectedRussianVoiceIdentifier
    }

    private func migrateLegacyVoiceSelection() {
        guard !legacyVoiceIdentifier.isEmpty,
              let legacyVoice = AVSpeechSynthesisVoice(identifier: legacyVoiceIdentifier) else { return }
        if legacyVoice.language.hasPrefix("uk"), selectedUkrainianVoiceIdentifier.isEmpty {
            selectedUkrainianVoiceIdentifier = legacyVoiceIdentifier
        } else if legacyVoice.language.hasPrefix("ru"), selectedRussianVoiceIdentifier.isEmpty {
            selectedRussianVoiceIdentifier = legacyVoiceIdentifier
        }
        legacyVoiceIdentifier = ""
    }

    private func loadVoices() {
        let available = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("ru") || $0.language.hasPrefix("uk") }
            .sorted {
                if $0.language != $1.language { return $0.language < $1.language }
                if $0.quality.rawValue != $1.quality.rawValue {
                    return $0.quality.rawValue > $1.quality.rawValue
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        voices = available.map(JarvisVoiceOption.init(voice:))

        var selectedDefaults: [String] = []
        if selectedRussianVoiceIdentifier.isEmpty,
           let preferred = available.first(where: {
               $0.language.hasPrefix("ru") &&
               ($0.name.localizedCaseInsensitiveContains("Голос 1") ||
                $0.name.localizedCaseInsensitiveContains("Siri Voice 1"))
           }) {
            selectedRussianVoiceIdentifier = preferred.identifier
            selectedDefaults.append("русский Siri Voice 1")
        }

        if selectedUkrainianVoiceIdentifier.isEmpty {
            let lesyaVoices = available.filter {
                $0.language.hasPrefix("uk") &&
                ($0.name.localizedCaseInsensitiveContains("Леся") ||
                 $0.name.localizedCaseInsensitiveContains("Lesya"))
            }
            if let preferred = lesyaVoices.first(where: { $0.quality == .enhanced || $0.quality == .premium })
                ?? lesyaVoices.first {
                selectedUkrainianVoiceIdentifier = preferred.identifier
                selectedDefaults.append("украинский голос Леся")
            }
        }

        if available.isEmpty {
            statusMessage = "Системные русские и украинские голоса не обнаружены. Проверьте «Настройки → Универсальный доступ → Устный контент → Голоса»."
        } else if selectedDefaults.isEmpty {
            statusMessage = "Найдено голосов: \(available.count). Сохранённые настройки оставлены без изменений. Прослушайте образцы и выберите голос."
        } else {
            statusMessage = "Найдено голосов: \(available.count). Автоматически выбран доступный вариант: \(selectedDefaults.joined(separator: ", ")). Его можно изменить."
        }
    }

    private func preview(_ option: JarvisVoiceOption) {
        synthesizer.stopSpeaking(at: .immediate)
        let text = option.voice.language.hasPrefix("uk")
            ? "Вітаю. Я ваш цифровий помічник. Чим можу допомогти?"
            : "Здравствуйте. Я ваш цифровой помощник. Чем могу помочь?"
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = option.voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
        statusMessage = "Воспроизводится образец: \(option.voice.name)."
    }
}
