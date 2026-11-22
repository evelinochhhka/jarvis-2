import SwiftUI
import JarvisCore

struct JarvisWorkspaceView: View {
    @State private var selectedList: JarvisWorkspaceList = .tasks
    @State private var entries: [JarvisWorkspaceEntry] = []
    @State private var draft = ""
    @State private var reminderDate = Date().addingTimeInterval(3600)
    @State private var reminderRepeat: JarvisReminderRepeat = .none
    @State private var errorMessage: String?
    private let store = JarvisWorkspaceStore()
    private let reminderScheduler = JarvisReminderScheduler()

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

            if selectedList == .reminders {
                DatePicker("Дата и время", selection: $reminderDate, in: Date()...)
                Picker("Повтор", selection: $reminderRepeat) {
                    ForEach(JarvisReminderRepeat.allCases, id: \.self) { frequency in
                        Text(frequency.title).tag(frequency)
                    }
                }
                .pickerStyle(.menu)
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
                    Text("Добавьте первую запись в раздел «\(selectedList.title)».")
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
                                if let reminder = entry.reminder {
                                    Text(reminder.date, style: .date)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(reminder.repeatFrequency.title)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(entry.createdAt, style: .date)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
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
                let schedule = selectedList == .reminders
                    ? JarvisReminderSchedule(date: reminderDate, repeatFrequency: reminderRepeat)
                    : nil
                let entry = try await store.add(to: selectedList, title: title, reminder: schedule)
                draft = ""
                var schedulingError: String?
                if selectedList == .reminders {
                    do {
                        try await reminderScheduler.schedule(entry)
                    } catch {
                        schedulingError = "Напоминание сохранено, но системное уведомление не включено. Проверьте разрешения и дату."
                    }
                }
                await reload()
                if let schedulingError { errorMessage = schedulingError }
            } catch {
                errorMessage = "Не удалось сохранить запись."
            }
        }
    }

    private func setCompleted(_ entry: JarvisWorkspaceEntry, to value: Bool) {
        Task {
            do {
                try await store.setCompleted(id: entry.id, isCompleted: value)
                if value { reminderScheduler.cancel(entryID: entry.id) }
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
                reminderScheduler.cancel(entryID: entry.id)
                await reload()
            } catch {
                errorMessage = "Не удалось удалить запись."
            }
        }
    }
}
