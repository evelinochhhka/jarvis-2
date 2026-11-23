import SwiftUI
import UniformTypeIdentifiers

private struct JarvisLocalFile: Identifiable {
    let url: URL
    let size: Int64
    let modifiedAt: Date
    var id: String { url.lastPathComponent }
}

struct JarvisFilesView: View {
    @State private var files: [JarvisLocalFile] = []
    @State private var showingImporter = false
    @State private var fileToRename: JarvisLocalFile?
    @State private var renameDraft = ""
    @State private var errorMessage: String?
    @State private var showingRename = false

    var body: some View {
        List {
            Section {
                Text("Файлы копируются в локальное хранилище JARVIS на этом устройстве. Они не загружаются в облако и не синхронизируются с другими устройствами.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    showingImporter = true
                } label: {
                    Label("Добавить файлы из приложения «Файлы»", systemImage: "plus")
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section("Мои файлы") {
                if files.isEmpty {
                    ContentUnavailableView(
                        "Пока нет файлов",
                        systemImage: "doc",
                        description: Text("Добавьте документ, изображение или другой файл через системный выбор.")
                    )
                } else {
                    ForEach(files) { file in
                        HStack(spacing: 12) {
                            Image(systemName: iconName(for: file.url))
                                .font(.title2)
                                .foregroundStyle(.secondary)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(file.url.lastPathComponent)
                                    .lineLimit(2)
                                Text("\(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file)) · \(file.modifiedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 4)
                            ShareLink(item: file.url) {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .accessibilityLabel("Поделиться файлом")
                            Menu {
                                Button("Переименовать", systemImage: "pencil") {
                                    fileToRename = file
                                    renameDraft = file.url.deletingPathExtension().lastPathComponent
                                    showingRename = true
                                }
                                Button("Удалить", systemImage: "trash", role: .destructive) {
                                    delete(file)
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .padding(.horizontal, 4)
                            }
                            .accessibilityLabel("Действия с файлом")
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Файлы")
        .onAppear(perform: reload)
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true,
            onCompletion: importFiles
        )
        .alert("Переименовать файл", isPresented: $showingRename) {
            TextField("Название", text: $renameDraft)
            Button("Отмена", role: .cancel) { fileToRename = nil }
            Button("Сохранить", action: rename)
        } message: {
            Text("Расширение файла будет сохранено.")
        }
    }

    private var storageDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("JARVISFiles", isDirectory: true)
    }

    private func reload() {
        do {
            try FileManager.default.createDirectory(
                at: storageDirectory,
                withIntermediateDirectories: true
            )
            let urls = try FileManager.default.contentsOfDirectory(
                at: storageDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            files = urls.compactMap { url in
                guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) else {
                    return nil
                }
                return JarvisLocalFile(
                    url: url,
                    size: Int64(values.fileSize ?? 0),
                    modifiedAt: values.contentModificationDate ?? .distantPast
                )
            }
            .sorted { $0.modifiedAt > $1.modifiedAt }
            errorMessage = nil
        } catch {
            errorMessage = "Не удалось прочитать локальные файлы."
        }
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            try FileManager.default.createDirectory(
                at: storageDirectory,
                withIntermediateDirectories: true
            )
            for source in urls {
                let didAccess = source.startAccessingSecurityScopedResource()
                defer {
                    if didAccess { source.stopAccessingSecurityScopedResource() }
                }
                let fileName = uniqueFileName(for: source.lastPathComponent)
                let destination = storageDirectory.appendingPathComponent(fileName)
                try FileManager.default.copyItem(at: source, to: destination)
            }
            reload()
        } catch {
            errorMessage = "Не удалось импортировать один или несколько файлов. Проверьте доступ и свободное место."
        }
    }

    private func uniqueFileName(for original: String) -> String {
        let candidate = storageDirectory.appendingPathComponent(original)
        guard FileManager.default.fileExists(atPath: candidate.path) else { return original }
        let source = URL(fileURLWithPath: original)
        let base = source.deletingPathExtension().lastPathComponent
        let ext = source.pathExtension
        var index = 2
        while true {
            let name = ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)"
            if !FileManager.default.fileExists(atPath: storageDirectory.appendingPathComponent(name).path) {
                return name
            }
            index += 1
        }
    }

    private func rename() {
        guard let file = fileToRename else { return }
        let cleaned = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            errorMessage = "Название не должно быть пустым."
            return
        }
        let ext = file.url.pathExtension
        let newName = ext.isEmpty ? cleaned : "\(cleaned).\(ext)"
        let destination = storageDirectory.appendingPathComponent(newName)
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            errorMessage = "Файл с таким названием уже существует."
            return
        }
        do {
            try FileManager.default.moveItem(at: file.url, to: destination)
            fileToRename = nil
            reload()
        } catch {
            errorMessage = "Не удалось переименовать файл."
        }
    }

    private func delete(_ file: JarvisLocalFile) {
        do {
            try FileManager.default.removeItem(at: file.url)
            reload()
        } catch {
            errorMessage = "Не удалось удалить файл."
        }
    }

    private func iconName(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf": return "doc.richtext"
        case "jpg", "jpeg", "png", "heic", "gif", "webp": return "photo"
        case "doc", "docx", "rtf", "txt", "md": return "doc.text"
        case "xls", "xlsx", "csv": return "tablecells"
        case "ppt", "pptx", "key": return "rectangle.on.rectangle"
        case "mp3", "m4a", "wav", "aac": return "waveform"
        case "mp4", "mov", "m4v": return "video"
        default: return "doc"
        }
    }
}
