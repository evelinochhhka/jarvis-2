const PREFIX = "jarvis2";
const memoryFallback = new Map();

function getStorage() {
  try {
    return typeof window !== "undefined" && window.localStorage
      ? window.localStorage
      : null;
  } catch {
    return null;
  }
}

export function readValue(key, fallback = null) {
  const storageKey = `${PREFIX}:${key}`;
  const storage = getStorage();

  try {
    const raw = storage ? storage.getItem(storageKey) : memoryFallback.get(storageKey);
    if (raw == null) return fallback;
    return JSON.parse(raw);
  } catch {
    return fallback;
  }
}

export function writeValue(key, value) {
  const storageKey = `${PREFIX}:${key}`;
  const serialized = JSON.stringify(value);
  const storage = getStorage();

  try {
    if (storage) {
      storage.setItem(storageKey, serialized);
    } else {
      memoryFallback.set(storageKey, serialized);
    }
    return true;
  } catch (error) {
    const wrapped = new Error("Не удалось сохранить данные на этом устройстве.");
    wrapped.cause = error;
    throw wrapped;
  }
}

export function removeValue(key) {
  const storageKey = `${PREFIX}:${key}`;
  const storage = getStorage();

  try {
    if (storage) storage.removeItem(storageKey);
    memoryFallback.delete(storageKey);
  } catch (error) {
    const wrapped = new Error("Не удалось удалить локальные данные.");
    wrapped.cause = error;
    throw wrapped;
  }
}
