const DATABASE_NAME = "jarvis-2-local-files";
const DATABASE_VERSION = 1;
const STORE_NAME = "files";
const MAX_FILE_BYTES = 100 * 1024 * 1024;

function openDatabase() {
  if (!globalThis.indexedDB) {
    return Promise.reject(new Error("Локальное хранилище файлов не поддерживается этим браузером."));
  }
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DATABASE_NAME, DATABASE_VERSION);
    request.onupgradeneeded = () => {
      const database = request.result;
      if (!database.objectStoreNames.contains(STORE_NAME)) {
        const store = database.createObjectStore(STORE_NAME, { keyPath: "id" });
        store.createIndex("updatedAt", "updatedAt");
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error || new Error("Не удалось открыть хранилище файлов."));
    request.onblocked = () => reject(new Error("Хранилище файлов заблокировано другой вкладкой."));
  });
}

function makeId() {
  return globalThis.crypto?.randomUUID?.()
    || `file-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function transaction(database, mode, operation) {
  return new Promise((resolve, reject) => {
    const tx = database.transaction(STORE_NAME, mode);
    const request = operation(tx.objectStore(STORE_NAME));
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error || new Error("Операция с файлом не выполнена."));
    tx.onabort = () => reject(tx.error || new Error("Операция с файлом отменена."));
  }).finally(() => database.close());
}

export async function addStoredFile(file) {
  if (!(file instanceof Blob)) throw new TypeError("Выбран некорректный файл.");
  if (!file.size) throw new TypeError("Пустые файлы не сохраняются.");
  if (file.size > MAX_FILE_BYTES) throw new RangeError("Максимальный размер одного файла: 100 МБ.");
  const database = await openDatabase();
  const record = {
    id: makeId(),
    name: String(file.name || "Файл").slice(0, 180),
    type: file.type || "application/octet-stream",
    size: file.size,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    blob: file
  };
  await transaction(database, "readwrite", store => store.add(record));
  return { ...record, blob: undefined };
}

export async function getStoredFiles() {
  const database = await openDatabase();
  const records = await transaction(database, "readonly", store => store.getAll());
  return records
    .map(({ blob, ...metadata }) => metadata)
    .sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
}

export async function getStoredFile(id) {
  const database = await openDatabase();
  return transaction(database, "readonly", store => store.get(id));
}

export async function renameStoredFile(id, name) {
  if (typeof name !== "string" || !name.trim()) throw new TypeError("Имя файла не должно быть пустым.");
  const database = await openDatabase();
  const record = await new Promise((resolve, reject) => {
    const tx = database.transaction(STORE_NAME, "readwrite");
    const store = tx.objectStore(STORE_NAME);
    const request = store.get(id);
    request.onsuccess = () => {
      if (!request.result) {
        reject(new Error("Файл не найден."));
        tx.abort();
        return;
      }
      const updated = { ...request.result, name: name.trim().slice(0, 180), updatedAt: new Date().toISOString() };
      store.put(updated);
      resolve({ ...updated, blob: undefined });
    };
    request.onerror = () => reject(request.error);
    tx.onabort = () => reject(tx.error || new Error("Не удалось переименовать файл."));
  }).finally(() => database.close());
  return record;
}

export async function deleteStoredFile(id) {
  const database = await openDatabase();
  return transaction(database, "readwrite", store => store.delete(id)).then(() => true);
}

export const FILE_STORE_LIMITS = Object.freeze({ maxFileBytes: MAX_FILE_BYTES });
