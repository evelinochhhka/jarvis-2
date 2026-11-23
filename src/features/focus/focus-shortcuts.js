const STORAGE_KEY = "jarvis-2.focus-shortcuts.v1";

const DEFAULT_SHORTCUTS = [
  { id: "dnd", label: "Не беспокоить", shortcut: "JARVIS - Не беспокоить" },
  { id: "sleep", label: "Сон", shortcut: "JARVIS - Сон" },
  { id: "work", label: "Учёба", shortcut: "JARVIS - Учёба" },
  { id: "personal", label: "Личное", shortcut: "JARVIS - Личное" },
  { id: "off", label: "Выключить фокусирование", shortcut: "JARVIS - Выключить фокусирование" }
];

function element(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function readShortcuts() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || "null");
    if (!Array.isArray(saved)) return DEFAULT_SHORTCUTS.map(item => ({ ...item }));
    return DEFAULT_SHORTCUTS.map(item => {
      const custom = saved.find(entry => entry?.id === item.id);
      return { ...item, shortcut: typeof custom?.shortcut === "string" ? custom.shortcut : item.shortcut };
    });
  } catch {
    return DEFAULT_SHORTCUTS.map(item => ({ ...item }));
  }
}

function saveShortcuts(shortcuts) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(
    shortcuts.map(({ id, shortcut }) => ({ id, shortcut }))
  ));
}

function runShortcut(name) {
  const cleanName = name.trim();
  if (!cleanName) throw new Error("Укажите точное название команды в приложении «Команды».");
  const url = new URL("shortcuts://run-shortcut");
  url.searchParams.set("name", cleanName);
  window.location.assign(url.toString());
}

export function renderFocusShortcuts() {
  const panel = element("section", "panel");
  panel.style.marginTop = "14px";
  panel.append(element("div", "panel-title", "УПРАВЛЕНИЕ ФОКУСИРОВАНИЕМ"));

  const description = element("p", "module-notice",
    "JARVIS может передать команду приложению Apple «Команды». Для этого один раз создайте в нём команды с указанными названиями и действием «Установить фокус». После настройки эти кнопки смогут запускать их на текущем устройстве."
  );
  panel.append(description);

  const shortcuts = readShortcuts();
  const controls = element("div", "module-items");

  for (const item of shortcuts) {
    const row = element("div", "module-item");
    const main = element("div", "module-item-main");
    main.append(element("div", "module-item-title", item.label));
    const nameInput = element("input", "module-input");
    nameInput.value = item.shortcut;
    nameInput.maxLength = 120;
    nameInput.setAttribute("aria-label", `Название команды для режима «${item.label}»`);
    nameInput.autocomplete = "off";
    nameInput.spellcheck = false;
    main.append(nameInput);

    const launch = element("button", "module-button", "Запустить");
    launch.type = "button";
    launch.addEventListener("click", () => {
      const updated = shortcuts.map(entry =>
        entry.id === item.id ? { ...entry, shortcut: nameInput.value.trim() } : entry
      );
      try {
        saveShortcuts(updated);
        runShortcut(nameInput.value);
      } catch (error) {
        window.alert(error.message || "Не удалось открыть команду.");
      }
    });

    row.append(main, launch);
    controls.append(row);
  }

  panel.append(controls);

  const openShortcuts = element("button", "module-button", "Открыть приложение «Команды»");
  openShortcuts.type = "button";
  openShortcuts.addEventListener("click", () => {
    window.location.assign("shortcuts://");
  });
  panel.append(openShortcuts);

  panel.append(element("p", "module-notice",
    "Названия команд можно изменить под ваши собственные режимы. Для каждого режима создайте команду, которая включает соответствующий фокус; отдельная команда должна выключать фокусирование. Само приложение JARVIS не может напрямую менять системный фокус из веб-версии и не получает подтверждение, что iOS выполнила команду."
  ));
  return panel;
}
