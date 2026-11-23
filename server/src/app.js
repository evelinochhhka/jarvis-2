import { createServer } from "node:http";
import { randomUUID, timingSafeEqual } from "node:crypto";
import { ProviderError } from "./providers/openai-compatible.js";

const API_PREFIX = "/api/v1";
const MAX_RATE_LIMIT_CLIENTS = 10_000;

function createRateLimiter({ windowMs, maxRequests }) {
  const clients = new Map();
  return (clientKey, now = Date.now()) => {
    let entry = clients.get(clientKey);
    if (!entry || entry.resetAt <= now) {
      entry = { count: 0, resetAt: now + windowMs };
      clients.set(clientKey, entry);
    }
    entry.count += 1;

    if (clients.size > MAX_RATE_LIMIT_CLIENTS) {
      for (const [key, value] of clients) {
        if (value.resetAt <= now) clients.delete(key);
      }
      while (clients.size > MAX_RATE_LIMIT_CLIENTS) {
        const oldestKey = clients.keys().next().value;
        if (oldestKey === undefined) break;
        clients.delete(oldestKey);
      }
    }

    return {
      allowed: entry.count <= maxRequests,
      retryAfterSeconds: Math.max(1, Math.ceil((entry.resetAt - now) / 1000))
    };
  };
}

function hasValidBearerToken(request, expectedToken) {
  if (!expectedToken) return true;
  const header = request.headers.authorization || "";
  if (!header.startsWith("Bearer ")) return false;
  const supplied = Buffer.from(header.slice(7), "utf8");
  const expected = Buffer.from(expectedToken, "utf8");
  return supplied.length === expected.length && timingSafeEqual(supplied, expected);
}

function sendJson(response, status, payload, origin) {
  response.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    ...(origin ? {
      "Access-Control-Allow-Origin": origin,
      "Vary": "Origin"
    } : {})
  });
  response.end(JSON.stringify(payload));
}

function readJson(request, maxBytes) {
  return new Promise((resolve, reject) => {
    let body = "";
    let size = 0;
    let tooLarge = false;
    request.setEncoding("utf8");
    request.on("data", (chunk) => {
      if (tooLarge) return;
      size += Buffer.byteLength(chunk, "utf8");
      if (size > maxBytes) {
        tooLarge = true;
        body = "";
        return;
      }
      body += chunk;
    });
    request.on("end", () => {
      if (tooLarge) {
        reject(Object.assign(new Error("Размер запроса превышает допустимый предел."), {
          status: 413,
          code: "REQUEST_TOO_LARGE"
        }));
        return;
      }
      try {
        resolve(JSON.parse(body || "{}"));
      } catch {
        reject(Object.assign(new Error("Некорректный JSON."), {
          status: 400,
          code: "INVALID_JSON"
        }));
      }
    });
    request.on("error", reject);
  });
}

function validateChatPayload(payload) {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return { error: "Ожидается JSON-объект." };
  }
  if (typeof payload.message !== "string" || !payload.message.trim()) {
    return { error: "Введите текст сообщения." };
  }
  if (payload.message.length > 6000) {
    return { error: "Сообщение слишком длинное. Максимум 6000 символов." };
  }
  if (payload.language !== undefined && !["auto", "ru", "uk"].includes(payload.language)) {
    return { error: "Поле language должно быть auto, ru или uk." };
  }
  if (payload.preferredLanguage !== undefined && !["ru", "uk"].includes(payload.preferredLanguage)) {
    return { error: "Поле preferredLanguage должно быть ru или uk." };
  }
  if (payload.history !== undefined) {
    if (!Array.isArray(payload.history) || payload.history.length > 30) {
      return { error: "История должна содержать не более 30 сообщений." };
    }
    for (const item of payload.history) {
      if (!item || typeof item !== "object" || !["user", "assistant"].includes(item.role)
          || typeof item.content !== "string" || !item.content.trim() || item.content.length > 6000) {
        return { error: "Каждое сообщение истории должно содержать роль user/assistant и текст до 6000 символов." };
      }
    }
  }
  if (payload.conversationId !== undefined
      && (typeof payload.conversationId !== "string" || payload.conversationId.length > 128)) {
    return { error: "Некорректный conversationId." };
  }
  return null;
}

export function createAppServer({ config, provider }) {
  const checkRateLimit = createRateLimiter({
    windowMs: config.rateLimitWindowMs || 60_000,
    maxRequests: config.rateLimitMaxRequests || 20
  });

  return createServer(async (request, response) => {
    const origin = request.headers.origin || "";
    const allowedOrigin = config.appOrigin && origin === config.appOrigin ? origin : "";
    let path;
    try {
      path = new URL(request.url || "/", "http://localhost").pathname;
    } catch {
      sendJson(response, 400, {
        error: { code: "INVALID_URL", message: "Некорректный адрес запроса." }
      });
      return;
    }

    if (origin && config.appOrigin && origin !== config.appOrigin) {
      sendJson(response, 403, { error: { code: "ORIGIN_NOT_ALLOWED", message: "Источник запроса не разрешён." } });
      return;
    }

    if (request.method === "OPTIONS") {
      response.writeHead(204, {
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Accept, Authorization",
        "Access-Control-Max-Age": "600",
        ...(allowedOrigin ? { "Access-Control-Allow-Origin": allowedOrigin, Vary: "Origin" } : {})
      });
      response.end();
      return;
    }

    if (request.method === "GET" && path === `${API_PREFIX}/health`) {
      sendJson(response, 200, {
        status: "ok",
        apiVersion: "v1",
        aiConfigured: config.isAiConfigured
      }, allowedOrigin);
      return;
    }

    if (request.method === "POST" && path === `${API_PREFIX}/chat`) {
      if (!hasValidBearerToken(request, config.apiAccessToken || "")) {
        sendJson(response, 401, {
          error: { code: "UNAUTHORIZED", message: "Для доступа к JARVIS требуется действительный токен." }
        }, allowedOrigin);
        return;
      }
      const clientKey = request.socket.remoteAddress || "unknown";
      const limit = checkRateLimit(clientKey);
      if (!limit.allowed) {
        response.setHeader("Retry-After", String(limit.retryAfterSeconds));
        sendJson(response, 429, {
          error: { code: "RATE_LIMITED", message: "Слишком много запросов. Подождите немного и повторите." }
        }, allowedOrigin);
        return;
      }

      if (!config.isAiConfigured) {
        sendJson(response, 503, {
          error: { code: "AI_NOT_CONFIGURED", message: "ИИ пока не настроен на сервере." }
        }, allowedOrigin);
        return;
      }

      try {
        const payload = await readJson(request, config.maxRequestBytes);
        const validationError = validateChatPayload(payload);
        if (validationError) {
          sendJson(response, 400, {
            error: { code: "INVALID_REQUEST", message: validationError.error }
          }, allowedOrigin);
          return;
        }

        const content = await provider.generateReply({
          message: payload.message.trim(),
          language: payload.language || "auto",
          preferredLanguage: payload.preferredLanguage || "ru",
          history: payload.history || []
        });

        sendJson(response, 200, {
          conversationId: typeof payload.conversationId === "string" ? payload.conversationId : randomUUID(),
          language: payload.language === "uk" ? "uk" : payload.language === "ru" ? "ru" : payload.preferredLanguage || "ru",
          message: {
            id: randomUUID(),
            role: "assistant",
            content,
            createdAt: new Date().toISOString()
          }
        }, allowedOrigin);
      } catch (error) {
        const status = error instanceof ProviderError ? error.status : error.status || 500;
        const code = error instanceof ProviderError ? error.code : error.code || "SERVER_ERROR";
        const message = status >= 500 && !(error instanceof ProviderError)
          ? "Внутренняя ошибка сервера."
          : error.message || "Не удалось обработать запрос.";
        sendJson(response, status, { error: { code, message } }, allowedOrigin);
      }
      return;
    }

    sendJson(response, 404, {
      error: { code: "NOT_FOUND", message: "Маршрут не найден." }
    }, allowedOrigin);
  });
}
