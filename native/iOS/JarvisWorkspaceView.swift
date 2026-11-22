import SwiftUI
import JarvisCore

struct JarvisWorkspaceView: View {
    @State private var selectedList: JarvisWorkspaceList = .tasks
    @State private var entries: [JarvisWorkspaceEntry] = []
    @State private var draft = ""
    @State private var errorMessage: String?
    private let store = JarvisWorkspaceStore()

    var body: some View {
        VStack(spacing: 12) {
            Picker("Раздел", selection: $selectedList) {
                ForEach(JarvisWorkspaceList.allCases, id: \.self) { list in
                    Text(list.title).tag(list)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                TextField("Новая запись", text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                Button(action: addEntry) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Добавить запись")
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray").font(.largeTitle).foregroundStyle(.secondary)
                    Text("Пока пусто").font(.headline)
                    Text("Добавьте первую запись в раздел «\\(selectedList.title)».")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Spacer()
            } else {
                List {
                    ForEach(entries) { entry in
                        HStack(spacing: 10) {
                            Button {
                                setCompleted(entry, to: !entry.isCompleted)
                            } label: {
                                Image(systemName: entry.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(entry.isCompleted ? .green : .secondary)
                            }
                            .buttonStyle(.plain)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.title)
                                    .strikethrough(entry.isCompleted)
                                    .foregroundStyle(entry.isCompleted ? .secondary : .primary)
                                Text(entry.createdAt, style: .date)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 4)
                            Button(role: .destructive) {
                                deleteEntry(entry)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Удалить запись")
                        }
                        .padding(.vertical, 3)
                    }
                }
                .listStyle(.plain)
            }
        }
        .padding()
        .navigationTitle("Мои списки")
        .task { await reload() }
        .onChange(of: selectedList) { _ in Task { await reload() } }
    }

    private func reload() async {
        do {
            entries = try await store.all(in: selectedList)
            errorMessage = nil
        } catch {
            errorMessage = "Не удалось загрузить записи."
        }
    }

    private func addEntry() {
        let title = draft
        Task {
            do {
                _ = try await store.add(to: selectedList, title: title)
                draft = ""
                await reload()
            } catch {
                errorMessage = "Не удалось сохранить запись."
            }
        }
    }

    private func setCompleted(_ entry: JarvisWorkspaceEntry, to value: Bool) {
        Task {
            do {
                try await store.setCompleted(id: entry.id, isCompleted: value)
                await reload()
            } catch {
                errorMessage = "Не удалось обновить запись."
            }
        }
    }

    private func deleteEntry(_ entry: JarvisWorkspaceEntry) {
        Task {
            do {
                try await store.delete(id: entry.id)
                await reload()
            } catch {
                errorMessage = "Не удалось удалить запись."
            }
        }
    }
}
