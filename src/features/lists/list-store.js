import { readValue, writeValue } from "../../services/storage/local-store.js";

const STORAGE_KEY = "user-data-v1";
const LIST_TYPES = ["tasks", "watchlist", "wishlist", "reminders"];

const DEFAULT_DATA = {
  version: 1,
  lists: {
    tasks: [],
    watchlist: [],
    wishlist: [],
    reminders: []
  }
};

function createId() {
  if (globalThis.crypto && typeof globalThis.crypto.randomUUID === "function") {
    return globalThis.crypto.randomUUID();
  }
  return `item-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function cleanText(value, fieldName) {
  if (typeof value !== "string" || !value.trim()) {
    throw new TypeError(`Поле «${fieldName}» не должно быть пустым.`);
  }
  return value.trim().slice(0, 500);
}

function readData() {
  const stored = readValue(STORAGE_KEY, null);
  if (!stored || stored.version !== 1 || !stored.lists) {
    return structuredCloneSafe(DEFAULT_DATA);
  }

  const lists = {};
  for (const type of LIST_TYPES) {
    lists[type] = Array.isArray(stored.lists[type]) ? stored.lists[type] : [];
  }
  return { version: 1, lists };
}

function structuredCloneSafe(value) {
  return JSON.parse(JSON.stringify(value));
}

function saveData(data) {
  writeValue(STORAGE_KEY, data);
  return data;
}

function assertListType(type) {
  if (!LIST_TYPES.includes(type)) {
    throw new TypeError("Неизвестный тип списка.");
  }
}

export function getListTypes() {
  return [...LIST_TYPES];
}

export function getItems(type) {
  assertListType(type);
  return readData().lists[type].map((item) => ({ ...item }));
}

export function addItem(type, input) {
  assertListType(type);
  if (!input || typeof input !== "object") {
    throw new TypeError("Не переданы данные элемента.");
  }

  const now = new Date().toISOString();
  const item = {
    id: createId(),
    title: cleanText(input.title, "название"),
    note: typeof input.note === "string" ? input.note.trim().slice(0, 2000) : "",
    completed: false,
    createdAt: now,
    updatedAt: now
  };

  if (type === "reminders") {
    if (typeof input.dueAt !== "string" || Number.isNaN(Date.parse(input.dueAt))) {
      throw new TypeError("Для напоминания укажите корректные дату и время.");
    }
    item.dueAt = new Date(input.dueAt).toISOString();
    item.timeZone = input.timeZone || Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC";
    item.repeat = input.repeat && typeof input.repeat === "object"
      ? {
          frequency: ["none", "daily", "weekly", "monthly"].includes(input.repeat.frequency)
            ? input.repeat.frequency
            : "none",
          interval: Math.max(1, Math.min(30, Number(input.repeat.interval) || 1))
        }
      : { frequency: "none", interval: 1 };
    item.enabled = true;
  }

  const data = readData();
  data.lists[type].unshift(item);
  saveData(data);
  return { ...item };
}

export function updateItem(type, id, changes) {
  assertListType(type);
  const data = readData();
  const index = data.lists[type].findIndex((item) => item.id === id);
  if (index < 0) return null;

  const current = data.lists[type][index];
  const next = { ...current };

  if (Object.hasOwn(changes, "title")) next.title = cleanText(changes.title, "название");
  if (Object.hasOwn(changes, "note")) {
    next.note = typeof changes.note === "string" ? changes.note.trim().slice(0, 2000) : "";
  }
  if (Object.hasOwn(changes, "completed")) next.completed = Boolean(changes.completed);

  if (type === "reminders") {
    if (Object.hasOwn(changes, "dueAt")) {
      if (typeof changes.dueAt !== "string" || Number.isNaN(Date.parse(changes.dueAt))) {
        throw new TypeError("Укажите корректные дату и время.");
      }
      next.dueAt = new Date(changes.dueAt).toISOString();
    }
    if (Object.hasOwn(changes, "enabled")) next.enabled = Boolean(changes.enabled);
    if (Object.hasOwn(changes, "repeat")) {
      const repeat = changes.repeat || {};
      next.repeat = {
        frequency: ["none", "daily", "weekly", "monthly"].includes(repeat.frequency)
          ? repeat.frequency
          : "none",
        interval: Math.max(1, Math.min(30, Number(repeat.interval) || 1))
      };
    }
  }

  next.updatedAt = new Date().toISOString();
  data.lists[type][index] = next;
  saveData(data);
  return { ...next };
}

export function deleteItem(type, id) {
  assertListType(type);
  const data = readData();
  const before = data.lists[type].length;
  data.lists[type] = data.lists[type].filter((item) => item.id !== id);
  if (data.lists[type].length === before) return false;
  saveData(data);
  return true;
}

export function exportAllLists() {
  return structuredCloneSafe(readData());
}

export function importAllLists(payload) {
  if (!payload || payload.version !== 1 || !payload.lists) {
    throw new TypeError("Файл резервной копии имеет неподдерживаемый формат.");
  }

  const next = { version: 1, lists: {} };
  for (const type of LIST_TYPES) {
    if (!Array.isArray(payload.lists[type])) {
      throw new TypeError(`В резервной копии отсутствует список «${type}».`);
    }
    next.lists[type] = payload.lists[type];
  }
  saveData(next);
  return exportAllLists();
}
