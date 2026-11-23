function getApiBase() {
  const configured = localStorage.getItem("jarvis-2-api-base-url") || "";
  if (!configured) return "/api/v1";
  try {
    const parsed = new URL(configured);
    if (!["https:", "http:"].includes(parsed.protocol)) return "/api/v1";
    return `${parsed.origin}/api/v1`;
  } catch {
    return "/api/v1";
  }
}

export class ApiError extends Error {
  constructor(message, status = 0, code = "API_ERROR") {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.code = code;
  }
}

async function request(path, options = {}) {
  let response;

  try {
    response = await fetch(`${getApiBase()}${path}`, {
      ...options,
      headers: {
        Accept: "application/json",
        ...(sessionStorage.getItem("jarvis-2-api-access-token")
          ? { Authorization: `Bearer ${sessionStorage.getItem("jarvis-2-api-access-token")}` }
          : {}),
        ...(options.body ? { "Content-Type": "application/json" } : {}),
        ...options.headers
      },
      credentials: "same-origin"
    });
  } catch (error) {
    throw new ApiError(
      "Сервер JARVIS 2 пока недоступен. Локальные списки продолжают работать на этом устройстве.",
      0,
      "NETWORK_UNAVAILABLE"
    );
  }

  const payload = await response.json().catch(() => null);
  if (!response.ok) {
    const code = payload?.error?.code || "HTTP_ERROR";
    const message = payload?.error?.message || (
      response.status === 404
        ? "Серверный модуль ещё не установлен."
        : "Сервер не смог обработать запрос."
    );
    throw new ApiError(message, response.status, code);
  }
  return payload;
}

export function checkServer() {
  return request("/health", { method: "GET" });
}

export function sendChatMessage({ message, conversationId = null, clientRequestId, history = [] }) {
  if (typeof message !== "string" || !message.trim()) {
    throw new TypeError("Введите сообщение.");
  }

  return request("/chat", {
    method: "POST",
    body: JSON.stringify({
      message: message.trim(),
      conversationId,
      clientRequestId,
      history: Array.isArray(history) ? history.slice(-20) : []
    })
  });
}

export function listPushReminders() {
  return request("/push/reminders", { method: "GET" });
}

export function savePushReminder(reminder) {
  return request("/push/reminders", {
    method: "POST",
    body: JSON.stringify({
      id: reminder.id,
      title: reminder.title,
      body: reminder.note || "",
      dueAt: reminder.dueAt,
      timeZone: reminder.timeZone || "UTC",
      repeat: reminder.repeat || { frequency: "none", interval: 1 }
    })
  });
}

export function deletePushReminder(id) {
  return request(`/push/reminders/${encodeURIComponent(id)}`, { method: "DELETE" });
}
