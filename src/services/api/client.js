const API_BASE = "/api/v1";

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
    response = await fetch(`${API_BASE}${path}`, {
      ...options,
      headers: {
        Accept: "application/json",
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
