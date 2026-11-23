import SwiftUI

struct JarvisAISettingsView: View {
    @StateObject private var loader = JarvisMLXModelLoader.shared
    @State private var status = "Модель будет загружена в память iPad при первом запуске. Для первой загрузки нужен интернет."

    var body: some View {
        Form {
            Section("Локальный ИИ") {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Gemma 3 1B")
                            .font(.headline)
                        Text("Квантованная версия 4-bit · MLX")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if loader.isLoaded {
                        Label("Загружена", systemImage: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                }

                Button {
                    Task {
                        do {
                            _ = try await loader.model()
                            status = "Модель загружена. JARVIS может отвечать локально, без сервера."
                        } catch {
                            status = "Не удалось загрузить модель: \(error.localizedDescription)"
                        }
                    }
                } label: {
                    HStack {
                        Text(loader.isLoaded ? "ИИ готов" : "Загрузить ИИ на iPad")
                        Spacer()
                        if loader.isLoading { ProgressView() }
                    }
                }
                .disabled(loader.isLoading || loader.isLoaded)

                if loader.isLoading {
                    ProgressView(value: loader.progress)
                    Text("Загрузка модели: \(Int(loader.progress * 100))%")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Как это работает") {
                Label("Модель загружается из Hugging Face и затем хранится в кэше приложения на iPad.", systemImage: "ipad")
                Label("После первой загрузки генерация ответов выполняется на самом iPad и не требует Ollama или отдельного сервера.", systemImage: "wifi.slash")
                Label("Интернет понадобится для первоначальной загрузки модели и обновлений.", systemImage: "arrow.down.circle")
            }

            Section("Важно") {
                Text("Это компактная локальная модель. По качеству и скорости она уступает крупным облачным ИИ. Фактическую производительность и расход памяти нужно проверить на вашем iPad A16.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Локальный ИИ")
    }
}
