import { createServer } from "node:http";
import { randomUUID } from "node:crypto";
import { ProviderError } from "./providers/openai-compatible.js";

const API_PREFIX = "/api/v1";

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
    request.setEncoding("utf8");
    request.on("data", (chunk) => {
      size += Buffer.byteLength(chunk, "utf8");
      if (size > maxBytes) {
        reject(Object.assign(new Error("Размер запроса превышает допустимый предел."), {
          status: 413,
          code: "REQUEST_TOO_LARGE"
        }));
        request.destroy();
        return;
      }
      body += chunk;
    });
    request.on("end", () => {
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
  return null;
}

export function createAppServer({ config, provider }) {
  return createServer(async (request, response) => {
    const origin = request.headers.origin || "";
    const allowedOrigin = config.appOrigin && origin === config.appOrigin ? origin : "";
    const path = new URL(request.url || "/", "http://localhost").pathname;

    if (origin && config.appOrigin && origin !== config.appOrigin) {
      sendJson(response, 403, { error: { code: "ORIGIN_NOT_ALLOWED", message: "Источник запроса не разрешён." } });
      return;
    }

    if (request.method === "OPTIONS") {
      response.writeHead(204, {
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Accept",
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
          preferredLanguage: payload.preferredLanguage || "ru"
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
