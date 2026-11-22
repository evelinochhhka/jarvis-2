import SwiftUI
import UIKit

struct JarvisFocusShortcutsView: View {
    @State private var statusMessage = "Для каждого режима заранее создайте команду в приложении «Команды» с действием «Установить фокус»."
    private let shortcuts = [
        ("Не беспокоить", "JARVIS - Не беспокоить"),
        ("Сон", "JARVIS - Сон"),
        ("Учёба", "JARVIS - Учёба"),
        ("Личное", "JARVIS - Личное"),
        ("Выключить фокусирование", "JARVIS - Выключить фокусирование")
    ]

    var body: some View {
        List {
            Section("Режимы") {
                ForEach(shortcuts, id: \.1) { item in
                    Button {
                        launchShortcut(named: item.1)
                    } label: {
                        HStack {
                            Text(item.0)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Состояние") {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Фокусирование")
    }

    private func launchShortcut(named name: String) {
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "run-shortcut"
        components.queryItems = [URLQueryItem(name: "name", value: name)]
        guard let url = components.url else {
            statusMessage = "Не удалось сформировать ссылку на команду."
            return
        }
        UIApplication.shared.open(url, options: [:]) { opened in
            DispatchQueue.main.async {
                statusMessage = opened
                    ? "Команда передана приложению «Команды». Это не подтверждает, что режим фокусирования изменился."
                    : "Не удалось открыть команду. Проверьте её название в приложении «Команды»."
            }
        }
    }
}
