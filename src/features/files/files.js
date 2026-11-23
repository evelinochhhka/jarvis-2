import {
  addStoredFile,
  deleteStoredFile,
  getStoredFile,
  getStoredFiles,
  renameStoredFile
} from "./file-store.js";

function makeElement(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function formatSize(bytes) {
  if (bytes < 1024) return `${bytes} Б`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} КБ`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} МБ`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} ГБ`;
}

function formatDate(value) {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? "Дата неизвестна" : date.toLocaleString("ru-RU");
}

function safeFilename(value) {
  return value.replace(/[\\/:*?"<>|]/g, "_").trim().slice(0, 180) || "Файл";
}

export async function renderFiles(container) {
  const description = makeElement("p", "module-description",
    "Файлы хранятся локально в браузере на этом устройстве. Они не отправляются на сервер и не синхронизируются с iPhone, iPad или другими браузерами."
  );
  const toolbar = makeElement("div", "module-toolbar");
  const pickerLabel = makeElement("label", "module-button", "Добавить файлы");
  pickerLabel.style.display = "inline-flex";
  pickerLabel.style.alignItems = "center";
  pickerLabel.style.cursor = "pointer";
  const picker = makeElement("input");
  picker.type = "file";
  picker.multiple = true;
  picker.hidden = true;
  pickerLabel.append(picker);
  const count = makeElement("div", "module-item-meta", "");
  toolbar.append(pickerLabel, count);
  const notice = makeElement("p", "module-notice",
    "Поддерживается импорт нескольких файлов, переименование, скачивание и удаление. Очистка данных сайта браузера может удалить эту локальную библиотеку."
  );
  const list = makeElement("div", "module-items");
  container.append(description, toolbar, notice, list);

  async function refresh() {
    const files = await getStoredFiles();
    count.textContent = `${files.length} ${files.length === 1 ? "файл" : "файлов"}`;
    list.replaceChildren();
    if (!files.length) {
      list.append(makeElement("div", "module-empty", "Библиотека пока пуста. Добавьте файлы с устройства."));
      return;
    }

    for (const file of files) {
      const row = makeElement("article", "module-item");
      const main = makeElement("div", "module-item-main");
      main.append(makeElement("div", "module-item-title", file.name));
      main.append(makeElement("div", "module-item-meta",
        `${formatSize(file.size)} · ${formatDate(file.updatedAt)}`
      ));
      const actions = makeElement("div", "module-actions");
      const download = makeElement("button", "module-button", "Скачать");
      download.type = "button";
      download.addEventListener("click", async () => {
        try {
          const stored = await getStoredFile(file.id);
          if (!stored) throw new Error("Файл больше не найден в локальной библиотеке.");
          const url = URL.createObjectURL(stored.blob);
          const anchor = makeElement("a");
          anchor.href = url;
          anchor.download = stored.name;
          document.body.append(anchor);
          anchor.click();
          anchor.remove();
          window.setTimeout(() => URL.revokeObjectURL(url), 1000);
        } catch (error) {
          window.alert(error.message || "Не удалось скачать файл.");
        }
      });
      const rename = makeElement("button", "module-button", "Имя");
      rename.type = "button";
      rename.addEventListener("click", async () => {
        const nextName = window.prompt("Новое имя файла:", file.name);
        if (nextName === null) return;
        try {
          await renameStoredFile(file.id, safeFilename(nextName));
          await refresh();
        } catch (error) {
          window.alert(error.message || "Не удалось переименовать файл.");
        }
      });
      const remove = makeElement("button", "module-button danger", "Удалить");
      remove.type = "button";
      remove.addEventListener("click", async () => {
        if (!window.confirm(`Удалить «${file.name}» из библиотеки JARVIS 2? Исходный файл на устройстве не изменится.`)) return;
        try {
          await deleteStoredFile(file.id);
          await refresh();
        } catch (error) {
          window.alert(error.message || "Не удалось удалить файл.");
        }
      });
      actions.append(download, rename, remove);
      row.append(main, actions);
      list.append(row);
    }
  }

  picker.addEventListener("change", async () => {
    const selected = [...(picker.files || [])];
    if (!selected.length) return;
    picker.disabled = true;
    pickerLabel.firstChild.textContent = "Сохранение...";
    try {
      for (const file of selected) await addStoredFile(file);
      await refresh();
    } catch (error) {
      window.alert(error.message || "Не удалось сохранить файлы.");
    } finally {
      picker.value = "";
      picker.disabled = false;
      pickerLabel.firstChild.textContent = "Добавить файлы";
    }
  });

  try {
    await refresh();
  } catch {
    list.replaceChildren(makeElement("div", "module-empty",
      "Браузер не предоставил доступ к локальному хранилищу файлов. Проверьте настройки сайта или откройте приложение в актуальном Safari/Chrome."
    ));
    picker.disabled = true;
  }
}
