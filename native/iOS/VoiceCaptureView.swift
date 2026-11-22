import SwiftUI
import Speech
import AVFoundation

struct VoiceCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recognizer = OnDeviceSpeechCapture()

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: recognizer.isListening ? "waveform.circle.fill" : "mic.circle")
                    .font(.system(size: 64))
                Text(recognizer.transcript.isEmpty ? "Нажмите кнопку и произнесите команду" : recognizer.transcript)
                    .multilineTextAlignment(.center).padding()
                Button(recognizer.isListening ? "Остановить" : "Начать запись") {
                    recognizer.isListening ? recognizer.stop() : recognizer.start()
                }.buttonStyle(.borderedProminent)
                if let error = recognizer.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
                Text("Работает только при поддержке локального распознавания выбранного языка. При отсутствии on-device поддержки запись не переключается в облако.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding().navigationTitle("Голосовой ввод")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Закрыть") { dismiss() } } }
        }
    }
}

@MainActor
final class OnDeviceSpeechCapture: ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var isListening = false
    @Published var errorMessage: String?

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func start() {
        stop()
        errorMessage = nil
        let code = Locale.current.language.languageCode?.identifier == "uk" ? "uk-UA" : "ru-RU"
        guard let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: code)),
              speechRecognizer.isAvailable else {
            errorMessage = "Распознавание для выбранного языка сейчас недоступно."
            return
        }
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                guard status == .authorized else {
                    self.errorMessage = "Нет разрешения на распознавание речи."
                    return
                }
                self.beginCapture(speechRecognizer)
            }
        }
    }

    private func beginCapture(_ speechRecognizer: SFSpeechRecognizer) {
        guard speechRecognizer.supportsOnDeviceRecognition else {
            errorMessage = "Для выбранного языка нет подтверждённого офлайн-распознавания на этом устройстве."
            return
        }
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = true
            self.request = request
            let input = engine.inputNode
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) {
                buffer, _ in request.append(buffer)
            }
            engine.prepare()
            try engine.start()
            isListening = true
            task = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    if let result { self?.transcript = result.bestTranscription.formattedString }
                    if let error {
                        self?.errorMessage = error.localizedDescription
                        self?.stop()
                    }
                }
            }
        } catch {
            errorMessage = "Не удалось запустить микрофон: \(error.localizedDescription)"
            stop()
        }
    }

    func stop() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
