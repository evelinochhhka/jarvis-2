import SwiftUI
import JarvisCore

struct JarvisWorkspaceView: View {
    @State private var selectedList: JarvisWorkspaceList = .tasks
    @State private var entries: [JarvisWorkspaceEntry] = []
    @State private var draft = ""
    @State private var reminderDate = Date().addingTimeInterval(3600)
    @State private var reminderRepeat: JarvisReminderRepeat = .none
    @State private var errorMessage: String?
    @State private var editingEntry: JarvisWorkspaceEntry?
    @State private var editTitle = ""
    @State private var editReminderDate = Date().addingTimeInterval(3600)
    @State private var editReminderRepeat: JarvisReminderRepeat = .none
    @State private var showingEditor = false
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
                    Image(systemName: "plus.circle.fill").font(.title2)
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
                                    .foregroundColor(entry.isCompleted ? .green : .secondary)
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
                            Button {
                                beginEditing(entry)
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Изменить запись")
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
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                Form {
                    Section("Название") {
                        TextField("Название записи", text: $editTitle, axis: .vertical)
                            .lineLimit(1...4)
                    }
                    if editingEntry?.list == .reminders {
                        Section("Расписание") {
                            DatePicker("Дата и время", selection: $editReminderDate, in: Date()...)
                            Picker("Повтор", selection: $editReminderRepeat) {
                                ForEach(JarvisReminderRepeat.allCases, id: \.self) { frequency in
                                    Text(frequency.title).tag(frequency)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Изменить запись")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") { showingEditor = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Сохранить", action: saveEditing)
                            .disabled(editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
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

    private func beginEditing(_ entry: JarvisWorkspaceEntry) {
        editingEntry = entry
        editTitle = entry.title
        editReminderDate = entry.reminder?.date ?? Date().addingTimeInterval(3600)
        editReminderRepeat = entry.reminder?.repeatFrequency ?? .none
        showingEditor = true
    }

    private func saveEditing() {
        guard let entry = editingEntry else { return }
        let title = editTitle
        let schedule = entry.list == .reminders
            ? JarvisReminderSchedule(date: editReminderDate, repeatFrequency: editReminderRepeat)
            : nil
        Task {
            do {
                let updated = try await store.update(id: entry.id, title: title, reminder: schedule)
                reminderScheduler.cancel(entryID: entry.id)
                if updated.list == .reminders && !updated.isCompleted {
                    do {
                        try await reminderScheduler.schedule(updated)
                    } catch {
                        errorMessage = "Запись изменена, но уведомление не удалось перепланировать. Проверьте разрешения и дату."
                    }
                }
                showingEditor = false
                editingEntry = nil
                await reload()
            } catch {
                errorMessage = "Не удалось изменить запись."
            }
        }
    }

    private func setCompleted(_ entry: JarvisWorkspaceEntry, to value: Bool) {
        Task {
            do {
                try await store.setCompleted(id: entry.id, isCompleted: value)
                if value {
                    reminderScheduler.cancel(entryID: entry.id)
                } else if let refreshed = try await store.all(in: selectedList).first(where: { $0.id == entry.id }),
                          refreshed.list == .reminders {
                    do {
                        try await reminderScheduler.schedule(refreshed)
                    } catch {
                        errorMessage = "Запись активирована, но уведомление не удалось восстановить."
                    }
                }
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
