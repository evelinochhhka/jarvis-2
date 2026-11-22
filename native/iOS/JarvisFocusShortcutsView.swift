import SwiftUI
import UIKit

private struct JarvisFocusShortcut: Identifiable {
    let title: String
    let name: String
    var id: String { name }
}

struct JarvisFocusShortcutsView: View {
    @State private var statusMessage = "Для каждого режима заранее создайте команду в приложении «Команды» с действием «Установить фокус»."
    private let shortcuts = [
        JarvisFocusShortcut(title: "Не беспокоить", name: "JARVIS - Не беспокоить"),
        JarvisFocusShortcut(title: "Сон", name: "JARVIS - Сон"),
        JarvisFocusShortcut(title: "Учёба", name: "JARVIS - Учёба"),
        JarvisFocusShortcut(title: "Личное", name: "JARVIS - Личное"),
        JarvisFocusShortcut(title: "Выключить фокусирование", name: "JARVIS - Выключить фокусирование")
    ]

    var body: some View {
        List {
            Section("Режимы") {
                ForEach(shortcuts) { item in
                    Button {
                        launchShortcut(named: item.name)
                    } label: {
                        HStack {
                            Text(item.title)
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
