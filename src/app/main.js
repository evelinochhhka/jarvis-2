import {
  addItem,
  deleteItem,
  getItems,
  updateItem
} from "../features/lists/list-store.js";
import { sendChatMessage } from "../services/api/client.js";
import { renderCommunications } from "../features/communications/communications.js";

const dashboard = document.querySelector(".dashboard");
const navButtons = [...document.querySelectorAll(".nav-item[data-view]")];
const homeMarkup = dashboard?.innerHTML || "";

const views = {
  home: "Главная",
  chat: "Диалог",
  tasks: "Хочу сделать",
  watchlist: "Хочу посмотреть",
  wishlist: "Мои хотелки",
  reminders: "Напоминания",
  files: "Файлы",
  settings: "Настройки",
  communications: "Связь и уведомления"
};

const listConfig = {
  tasks: { title: "Хочу сделать", description: "Задачи и планы, которые вы хотите выполнить." },
  watchlist: { title: "Хочу посмотреть", description: "Фильмы, сериалы и видео, к которым вы хотите вернуться." },
  wishlist: { title: "Мои хотелки", description: "Покупки, идеи и желания, которые стоит сохранить." },
  reminders: { title: "Напоминания", description: "Локальное расписание. Пока без системных push-уведомлений." }
};

function addStyles() {
  const style = document.createElement("style");
  style.textContent = `
    .module-heading { margin: 0 0 8px; font-size: clamp(25px, 4vw, 36px); font-weight: 300; }
    .module-description { color: var(--muted); font-size: 12px; line-height: 1.7; margin-bottom: 24px; }
    .module-form { display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 10px; margin: 18px 0 22px; }
    .module-input, .module-textarea, .module-select { width: 100%; min-width: 0; padding: 12px 13px; color: var(--text); background: #11171b; border: 1px solid var(--line); border-radius: 3px; font: inherit; font-size: 13px; }
    .module-textarea { min-height: 76px; resize: vertical; grid-column: 1 / -1; }
    .module-input:focus, .module-textarea:focus, .module-select:focus { outline: 1px solid var(--blue); border-color: var(--blue); }
    .module-button { padding: 11px 16px; border: 1px solid var(--blue-dim); border-radius: 3px; background: #203039; color: var(--blue); cursor: pointer; font-size: 12px; }
    .module-button:hover { background: #2a414c; }
    .module-button.danger { border-color: #63464a; color: #d49a9a; background: #2a1e21; }
    .module-items { display: grid; gap: 9px; }
    .module-item { display: flex; align-items: flex-start; gap: 12px; padding: 15px; border: 1px solid var(--line); background: #171e22; }
    .module-item-main { min-width: 0; flex: 1; }
    .module-item-title { font-size: 14px; overflow-wrap: anywhere; }
    .module-item-note, .module-item-meta { color: var(--muted); font-size: 11px; line-height: 1.6; margin-top: 5px; overflow-wrap: anywhere; }
    .module-item.done .module-item-title { text-decoration: line-through; color: var(--muted); }
    .module-item input[type="checkbox"] { accent-color: var(--blue); margin-top: 3px; }
    .module-actions { display: flex; gap: 7px; }
    .module-actions button { padding: 6px 9px; }
    .module-empty { padding: 25px 18px; border: 1px dashed var(--line); color: var(--muted); font-size: 12px; text-align: center; }
    .module-notice { color: var(--muted); font-size: 11px; line-height: 1.6; margin-top: 12px; }
    .chat-log { display: grid; gap: 12px; margin: 20px 0; }
    .chat-message { max-width: 90%; padding: 13px 15px; border: 1px solid var(--line); background: #171e22; font-size: 13px; line-height: 1.7; white-space: pre-wrap; overflow-wrap: anywhere; }
    .chat-message.user { justify-self: end; border-color: #405763; background: #1c2a31; }
    .chat-message.system { max-width: 100%; color: #c2a7a7; }
    .chat-form { display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 9px; }
    .module-toolbar { display: flex; justify-content: space-between; align-items: center; gap: 12px; margin-bottom: 12px; }
    @media (max-width: 560px) {
      .module-form { grid-template-columns: 1fr; }
      .module-form .module-button { width: 100%; }
      .chat-form { grid-template-columns: 1fr; }
      .module-toolbar { align-items: flex-start; flex-direction: column; }
    }
  `;
  document.head.append(style);
}

function element(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function createModuleShell(title, description) {
  const shell = element("section", "module-screen");
  shell.append(element("div", "eyebrow", "PERSONAL ASSISTANT SYSTEM"));
  shell.append(element("h1", "module-heading", title));
  shell.append(element("p", "module-description", description));
  return shell;
}

function formatDate(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  return date.toLocaleString("ru-RU", {
    day: "numeric",
    month: "long",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit"
  });
}

function renderList(type) {
  const config = listConfig[type];
  const shell = createModuleShell(config.title, config.description);
  const form = element("form", "module-form");
  const title = element("input", "module-input");
  title.name = "title";
  title.placeholder = type === "reminders" ? "Текст напоминания" : "Название";
  title.maxLength = 500;
  title.required = true;
  title.setAttribute("aria-label", title.placeholder);

  const note = element("textarea", "module-textarea");
  note.name = "note";
  note.placeholder = "Заметка (необязательно)";
  note.maxLength = 2000;
  note.setAttribute("aria-label", "Заметка");

  let dueInput;
  let repeatSelect;
  if (type === "reminders") {
    dueInput = element("input", "module-input");
    dueInput.type = "datetime-local";
    dueInput.name = "dueAt";
    dueInput.required = true;
    dueInput.setAttribute("aria-label", "Дата и время напоминания");

    repeatSelect = element("select", "module-select");
    repeatSelect.name = "repeat";
    repeatSelect.setAttribute("aria-label", "Повторение");
    for (const [value, label] of [
      ["none", "Без повтора"],
      ["daily", "Каждый день"],
      ["weekly", "Каждую неделю"],
      ["monthly", "Каждый месяц"]
    ]) {
      const option = element("option", "", label);
      option.value = value;
      repeatSelect.append(option);
    }
  }

  const submit = element("button", "module-button", "Добавить");
  submit.type = "submit";
  form.append(title, submit, note);
  if (type === "reminders") form.append(dueInput, repeatSelect);
  shell.append(form);

  const toolbar = element("div", "module-toolbar");
  toolbar.append(element("div", "panel-title", "СОХРАНЁННЫЕ ЭЛЕМЕНТЫ"));
  const count = element("div", "module-item-meta", "");
  toolbar.append(count);
  shell.append(toolbar);

  const list = element("div", "module-items");
  shell.append(list);

  function refresh() {
    const items = getItems(type);
    count.textContent = String(items.length);
    list.replaceChildren();

    if (!items.length) {
      list.append(element("div", "module-empty", "Здесь пока ничего нет."));
      return;
    }

    for (const item of items) {
      const row = element("article", `module-item${item.completed ? " done" : ""}`);
      const checkbox = element("input");
      checkbox.type = "checkbox";
      checkbox.checked = type === "reminders" ? !item.enabled : item.completed;
      checkbox.setAttribute("aria-label", type === "reminders" ? "Отключить напоминание" : "Отметить выполненным");
      checkbox.addEventListener("change", () => {
        if (type === "reminders") updateItem(type, item.id, { enabled: !checkbox.checked });
        else updateItem(type, item.id, { completed: checkbox.checked });
        refresh();
      });

      const main = element("div", "module-item-main");
      main.append(element("div", "module-item-title", item.title));
      if (item.note) main.append(element("div", "module-item-note", item.note));

      if (type === "reminders") {
        const repeatLabel = {
          none: "Без повтора",
          daily: "Каждый день",
          weekly: "Каждую неделю",
          monthly: "Каждый месяц"
        }[item.repeat?.frequency || "none"];
        main.append(element("div", "module-item-meta", `${formatDate(item.dueAt)} · ${repeatLabel}${item.enabled ? "" : " · выключено"}`));
      } else {
        main.append(element("div", "module-item-meta", `Добавлено: ${formatDate(item.createdAt)}`));
      }

      const actions = element("div", "module-actions");
      const edit = element("button", "module-button", "Изменить");
      edit.type = "button";
      edit.addEventListener("click", () => {
        const nextTitle = window.prompt("Новое название:", item.title);
        if (nextTitle === null) return;
        const nextNote = window.prompt("Заметка:", item.note || "");
        if (nextNote === null) return;
        const changes = { title: nextTitle, note: nextNote };
        if (type === "reminders") {
          const currentDate = new Date(item.dueAt);
          const localDate = new Date(currentDate.getTime() - currentDate.getTimezoneOffset() * 60_000)
            .toISOString().slice(0, 16);
          const nextDueAt = window.prompt("Дата и время (ГГГГ-ММ-ДД ЧЧ:ММ):", localDate);
          if (nextDueAt === null) return;
          const nextRepeat = window.prompt(
            "Повтор: none, daily, weekly или monthly",
            item.repeat?.frequency || "none"
          );
          if (nextRepeat === null) return;
          if (!["none", "daily", "weekly", "monthly"].includes(nextRepeat)) {
            window.alert("Неизвестный тип повтора.");
            return;
          }
          const parsedDate = new Date(nextDueAt);
          if (Number.isNaN(parsedDate.getTime())) {
            window.alert("Не удалось распознать дату и время.");
            return;
          }
          changes.dueAt = parsedDate.toISOString();
          changes.repeat = { frequency: nextRepeat, interval: item.repeat?.interval || 1 };
        }
        try {
          updateItem(type, item.id, changes);
          refresh();
        } catch (error) {
          window.alert(error.message || "Не удалось изменить элемент.");
        }
      });
      const remove = element("button", "module-button danger", "Удалить");
      remove.type = "button";
      remove.addEventListener("click", () => {
        if (deleteItem(type, item.id)) refresh();
      });
      actions.append(edit, remove);
      row.append(checkbox, main, actions);
      list.append(row);
    }
  }

  form.addEventListener("submit", (event) => {
    event.preventDefault();
    try {
      const input = {
        title: title.value,
        note: note.value
      };
      if (type === "reminders") {
        input.dueAt = new Date(dueInput.value).toISOString();
        input.repeat = { frequency: repeatSelect.value, interval: 1 };
      }
      addItem(type, input);
      form.reset();
      refresh();
      title.focus();
    } catch (error) {
      window.alert(error.message || "Не удалось сохранить элемент.");
    }
  });

  shell.append(element("p", "module-notice",
    type === "reminders"
      ? "Напоминания сохраняются локально. Пока приложение не отправляет системные уведомления и не запускает повторения автоматически."
      : "Данные сохраняются в браузере на этом устройстве и пока не синхронизируются с другими устройствами."
  ));
  refresh();
  return shell;
}

function renderChat() {
  const shell = createModuleShell("Диалог", "История диалога сохраняется локально на этом устройстве. Ответы ИИ требуют настроенного сервера.");
  const log = element("div", "chat-log");
  const storageKey = "jarvis-2-chat-v1";
  let saved = null;
  try {
    saved = JSON.parse(localStorage.getItem(storageKey) || "null");
  } catch {
    saved = null;
  }
  const conversationId = typeof saved?.conversationId === "string"
    ? saved.conversationId
    : globalThis.crypto?.randomUUID?.() || `conversation-${Date.now()}`;
  let history = Array.isArray(saved?.history)
    ? saved.history.filter((item) =>
        item && ["user", "assistant"].includes(item.role)
        && typeof item.content === "string" && item.content.trim()
      ).slice(-30)
    : [];

  if (!history.length) {
    log.append(element("div", "chat-message system",
      "Здравствуйте. Диалог будет продолжаться с учётом последних сообщений. Если сервер или ИИ не настроен, я сообщу об этом прямо."
    ));
  } else {
    for (const item of history) {
      log.append(element(
        "div",
        `chat-message${item.role === "user" ? " user" : ""}`,
        item.content
      ));
    }
  }

  const form = element("form", "chat-form");
  const input = element("textarea", "module-textarea");
  input.placeholder = "Введите сообщение...";
  input.rows = 2;
  input.required = true;
  input.setAttribute("aria-label", "Сообщение ассистенту");
  const send = element("button", "module-button", "Отправить");
  send.type = "submit";
  form.append(input, send);
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const message = input.value.trim();
    if (!message) return;
    log.append(element("div", "chat-message user", message));
    input.value = "";
    send.disabled = true;
    send.textContent = "Отправка...";
    try {
      const clientRequestId = globalThis.crypto?.randomUUID?.() || `request-${Date.now()}`;
      const result = await sendChatMessage({
        message,
        conversationId,
        clientRequestId,
        history: history.slice(-20)
      });
      const answer = result?.message?.content || "Сервер вернул пустой ответ.";
      log.append(element("div", "chat-message", answer));
      history = [
        ...history,
        { role: "user", content: message },
        { role: "assistant", content: answer }
      ].slice(-30);
      try {
        localStorage.setItem(storageKey, JSON.stringify({ conversationId, history }));
      } catch {
        log.append(element("div", "chat-message system",
          "Не удалось сохранить историю локально. Текущий диалог остаётся на экране."
        ));
      }
    } catch (error) {
      log.append(element("div", "chat-message system", error.message));
    } finally {
      send.disabled = false;
      send.textContent = "Отправить";
      log.scrollTop = log.scrollHeight;
    }
  });
  shell.append(log, form);
  return shell;
}

function renderSettings() {
  const shell = createModuleShell("Настройки", "Локальные данные JARVIS 2 и резервное копирование.");
  const panel = element("section", "panel");
  panel.append(element("div", "panel-title", "РЕЗЕРВНАЯ КОПИЯ"));

  const description = element("p", "module-description",
    "Экспорт сохранит все четыре списка в JSON-файл. Импорт заменит текущие локальные списки данными из выбранной копии."
  );
  panel.append(description);

  const toolbar = element("div", "module-toolbar");
  const exportButton = element("button", "module-button", "Экспортировать данные");
  exportButton.type = "button";
  exportButton.addEventListener("click", () => {
    try {
      const data = {
        version: 1,
        exportedAt: new Date().toISOString(),
        lists: {
          tasks: getItems("tasks"),
          watchlist: getItems("watchlist"),
          wishlist: getItems("wishlist"),
          reminders: getItems("reminders")
        }
      };
      const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" });
      const url = URL.createObjectURL(blob);
      const anchor = element("a");
      anchor.href = url;
      anchor.download = `jarvis-2-backup-${new Date().toISOString().slice(0, 10)}.json`;
      document.body.append(anchor);
      anchor.click();
      anchor.remove();
      URL.revokeObjectURL(url);
    } catch (error) {
      window.alert(error.message || "Не удалось создать резервную копию.");
    }
  });

  const importLabel = element("label", "module-button", "Импортировать копию");
  importLabel.style.display = "inline-flex";
  importLabel.style.alignItems = "center";
  importLabel.style.cursor = "pointer";
  const fileInput = element("input");
  fileInput.type = "file";
  fileInput.accept = "application/json,.json";
  fileInput.hidden = true;
  fileInput.addEventListener("change", async () => {
    const file = fileInput.files?.[0];
    if (!file) return;
    try {
      const parsed = JSON.parse(await file.text());
      if (!window.confirm("Импорт заменит все текущие локальные списки. Продолжить?")) {
        fileInput.value = "";
        return;
      }
      const { importAllLists } = await import("../features/lists/list-store.js");
      importAllLists(parsed);
      window.alert("Резервная копия восстановлена.");
    } catch (error) {
      window.alert(error.message || "Не удалось прочитать резервную копию.");
    } finally {
      fileInput.value = "";
    }
  });
  importLabel.append(fileInput);
  toolbar.append(exportButton, importLabel);
  panel.append(toolbar);
  panel.append(element("p", "module-notice",
    "Файл резервной копии содержит ваши личные записи. Храните его в безопасном месте и не публикуйте."
  ));
  shell.append(panel);

  const accessPanel = element("section", "panel");
  accessPanel.style.marginTop = "14px";
  accessPanel.append(element("div", "panel-title", "ДОСТУП К СЕРВЕРУ"));
  accessPanel.append(element("p", "module-description",
    "Токен нужен только если серверный администратор включил API_ACCESS_TOKEN. В этой вкладке он хранится временно и исчезнет после закрытия вкладки."
  ));
  const tokenInput = element("input", "module-input");
  tokenInput.type = "password";
  tokenInput.autocomplete = "off";
  tokenInput.placeholder = "Bearer-токен сервера";
  tokenInput.value = sessionStorage.getItem("jarvis-2-api-access-token") || "";
  tokenInput.setAttribute("aria-label", "Токен доступа к серверу");
  const tokenActions = element("div", "module-toolbar");
  const saveToken = element("button", "module-button", "Сохранить на эту сессию");
  saveToken.type = "button";
  saveToken.addEventListener("click", () => {
    const value = tokenInput.value.trim();
    if (value) sessionStorage.setItem("jarvis-2-api-access-token", value);
    else sessionStorage.removeItem("jarvis-2-api-access-token");
    window.alert(value ? "Токен сохранён только до закрытия вкладки." : "Токен удалён из этой сессии.");
  });
  const clearToken = element("button", "module-button danger", "Очистить");
  clearToken.type = "button";
  clearToken.addEventListener("click", () => {
    tokenInput.value = "";
    sessionStorage.removeItem("jarvis-2-api-access-token");
  });
  tokenActions.append(saveToken, clearToken);
  accessPanel.append(tokenInput, tokenActions);
  shell.append(accessPanel);

  const status = element("section", "panel");
  status.style.marginTop = "14px";
  status.append(element("div", "panel-title", "СОСТОЯНИЕ СИСТЕМЫ"));
  status.append(element("div", "system-row", "Локальное хранилище: активно"));
  status.append(element("div", "system-row", "Синхронизация между устройствами: не подключена"));
  status.append(element("div", "system-row", "ИИ и голос: не подключены"));
  shell.append(status);
  return shell;
}

function renderPlaceholder(view) {
  if (view === "settings") return renderSettings();
  const shell = createModuleShell("Файлы", "Локальная библиотека документов и вложений.");
  import("../features/files/files.js")
    .then(({ renderFiles }) => renderFiles(shell))
    .catch((error) => {
      shell.append(element("div", "module-empty", error.message || "Не удалось открыть библиотеку файлов."));
    });
  return shell;
}

function navigate(view) {
  if (!dashboard || !views[view]) return;
  navButtons.forEach((button) => {
    const active = button.dataset.view === view;
    button.classList.toggle("active", active);
    if (active) button.setAttribute("aria-current", "page");
    else button.removeAttribute("aria-current");
  });

  if (view === "home") {
    dashboard.innerHTML = homeMarkup;
  } else {
    dashboard.replaceChildren(
      view === "chat"
        ? renderChat()
        : view === "communications"
          ? renderCommunications()
          : listConfig[view]
          ? renderList(view)
          : renderPlaceholder(view)
    );
  }

  document.title = `${views[view]} | JARVIS 2`;
  if (window.innerWidth <= 900) {
    document.getElementById("app")?.classList.add("sidebar-hidden");
  }
}

function initialize() {
  if (!dashboard) return;
  addStyles();
  const sidebar = document.querySelector(".sidebar");
  const systemLabel = [...(sidebar?.querySelectorAll(".nav-label") || [])].at(-1);
  if (sidebar && systemLabel && !document.querySelector('[data-view="communications"]')) {
    const communicationsButton = element("button", "nav-item");
    communicationsButton.type = "button";
    communicationsButton.dataset.view = "communications";
    communicationsButton.append(
      element("span", "nav-icon", "◉"),
      document.createTextNode(" Связь и уведомления")
    );
    sidebar.insertBefore(communicationsButton, systemLabel);
    navButtons.push(communicationsButton);
  }

  navButtons.forEach((button) => {
    button.addEventListener("click", () => navigate(button.dataset.view));
  });
  navButtons.forEach((button) => {
    button.setAttribute("type", "button");
  });
  navigate("home");
}

initialize();
