import SwiftUI
import JarvisCore

struct JarvisMemoryView: View {
    @State private var items: [JarvisMemoryItem] = []
    @State private var key = ""
    @State private var value = ""
    @State private var errorMessage: String?
    private let store = JarvisMemoryStore()

    var body: some View {
        VStack(spacing: 12) {
            TextField("Что запомнить", text: $key)
                .textFieldStyle(.roundedBorder)
            TextField("Значение", text: $value, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
            Button(action: saveMemory) {
                Label("Сохранить в память", systemImage: "brain.head.profile")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      || value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            }

            List {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.key).font(.headline)
                        Text(item.value).font(.body)
                        Text("Обновлено: " + item.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                    .swipeActions {
                        Button(role: .destructive) {
                            delete(item)
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .padding()
        .navigationTitle("Память JARVIS")
        .task { await reload() }
    }

    private func reload() async {
        do {
            items = try await store.all()
            errorMessage = nil
        } catch {
            errorMessage = "Не удалось загрузить память."
        }
    }

    private func saveMemory() {
        let cleanKey = key
        let cleanValue = value
        Task {
            do {
                _ = try await store.remember(key: cleanKey, value: cleanValue)
                key = ""
                value = ""
                await reload()
            } catch {
                errorMessage = "Не удалось сохранить запись памяти."
            }
        }
    }

    private func delete(_ item: JarvisMemoryItem) {
        Task {
            do {
                try await store.forget(id: item.id)
                await reload()
            } catch {
                errorMessage = "Не удалось удалить запись памяти."
            }
        }
    }
}
