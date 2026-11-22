import AVFoundation
import Combine
import Speech

@MainActor
final class OnDeviceSpeechCapture: ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var isListening = false
    @Published private(set) var isPreparing = false
    @Published private(set) var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var captureGeneration: UUID?

    func start(localeIdentifier: String) {
        guard !isListening, !isPreparing else { return }
        transcript = ""
        errorMessage = nil
        isPreparing = true
        let generation = UUID()
        captureGeneration = generation
        Task {
            await beginCapture(localeIdentifier: localeIdentifier, generation: generation)
            if captureGeneration == generation {
                isPreparing = false
            }
        }
    }

    func stop() {
        captureGeneration = nil
        isPreparing = false
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func beginCapture(localeIdentifier: String, generation: UUID) async {
        let speechStatus = await requestSpeechAuthorization()
        guard captureGeneration == generation else { return }
        guard speechStatus == .authorized else {
            errorMessage = "Разрешите распознавание речи в настройках iPhone."
            return
        }

        let microphoneGranted = await requestMicrophonePermission()
        guard captureGeneration == generation else { return }
        guard microphoneGranted else {
            errorMessage = "Разрешите доступ к микрофону в настройках iPhone."
            return
        }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)),
              recognizer.isAvailable else {
            errorMessage = "Распознавание для выбранного языка сейчас недоступно."
            return
        }
        guard recognizer.supportsOnDeviceRecognition else {
            errorMessage = "Для выбранного языка недоступно офлайн-распознавание на этом устройстве."
            return
        }
        guard captureGeneration == generation else { return }

        speechRecognizer = recognizer
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = true
            recognitionRequest = request

            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            guard captureGeneration == generation else {
                stop()
                return
            }
            isListening = true

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard self?.captureGeneration == generation else { return }
                    if let result {
                        self?.transcript = result.bestTranscription.formattedString
                    }
                    if let error {
                        self?.errorMessage = error.localizedDescription
                        self?.stop()
                    } else if result?.isFinal == true {
                        self?.stop()
                    }
                }
            }
        } catch {
            if audioEngine.isRunning {
                audioEngine.stop()
                audioEngine.inputNode.removeTap(onBus: 0)
            }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            recognitionRequest = nil
            recognitionTask = nil
            isListening = false
            errorMessage = "Не удалось запустить микрофон: \(error.localizedDescription)"
        }
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        let current = SFSpeechRecognizer.authorizationStatus()
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        let session = AVAudioSession.sharedInstance()
        if session.recordPermission == .granted { return true }
        if session.recordPermission == .denied { return false }
        return await withCheckedContinuation { continuation in
            session.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
