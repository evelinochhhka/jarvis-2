import SwiftUI

struct JarvisAISettingsView: View {
    @AppStorage("jarvis2.api.baseURL") private var serverAddress = ""
    @State private var status = "Укажите HTTPS-адрес вашего JARVIS-сервера. Ключ модели хранится только на сервере."
    @State private var isChecking = false

    var body: some View {
        Form {
            Section("Сервер ИИ") {
                TextField("https://ваш-сервер.example", text: $serverAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                Button {
                    Task { await checkConnection() }
                } label: {
                    HStack {
                        Text("Проверить соединение")
                        Spacer()
                        if isChecking { ProgressView() }
                    }
                }
                .disabled(isChecking || serverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Безопасность") {
                Text("В приложении не должно быть API-ключа OpenRouter или другого провайдера. Он задаётся только в переменных окружения серверной части. Не вставляйте секретные ключи в это поле.")
                    .font(.footnote)
                Text("Для реального использования вне локальной сети нужен защищённый HTTPS-сервер с ограничением доступа.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Подключение ИИ")
    }

    private func checkConnection() async {
        isChecking = true
        defer { isChecking = false }
        let raw = serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = URL(string: raw),
              let scheme = base.scheme?.lowercased(),
              scheme == "https" || base.host == "localhost" || base.host == "127.0.0.1" else {
            status = "Введите корректный HTTPS-адрес. HTTP разрешён только для localhost."
            return
        }

        let url = base.appendingPathComponent("api/v1/health")
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                status = "Сервер ответил ошибкой. Проверьте адрес и настройки."
                return
            }
            struct Health: Decodable {
                let status: String
                let aiConfigured: Bool
            }
            let health = try JSONDecoder().decode(Health.self, from: data)
            status = health.aiConfigured
                ? "Соединение установлено. Сервер сообщает, что ИИ-провайдер настроен."
                : "Сервер доступен, но ИИ-провайдер ещё не настроен."
        } catch {
            status = "Не удалось связаться с сервером. Проверьте адрес и подключение."
        }
    }
}
