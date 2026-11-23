const DEFAULT_BASE_URL = "https://openrouter.ai/api/v1";

function readPositiveInteger(value, fallback, maximum) {
  const parsed = Number.parseInt(value || "", 10);
  if (!Number.isInteger(parsed) || parsed < 1) return fallback;
  return Math.min(parsed, maximum);
}

export function loadConfig(env = process.env) {
  const provider = (env.AI_PROVIDER || "openrouter").trim().toLowerCase();
  let baseUrl = (env.AI_BASE_URL || DEFAULT_BASE_URL).trim();
  while (baseUrl.endsWith("/")) baseUrl = baseUrl.slice(0, -1);
  const model = (env.AI_MODEL || "nvidia/nemotron-3-ultra-550b-a55b:free").trim();
  const apiKey = (env.AI_API_KEY || "").trim();
  const appOrigin = (env.APP_ORIGIN || "").trim();
  const apiAccessToken = (env.API_ACCESS_TOKEN || "").trim();
  const pushPublicKey = (env.VAPID_PUBLIC_KEY || "").trim();
  const pushPrivateKey = (env.VAPID_PRIVATE_KEY || "").trim();
  const pushSubject = (env.VAPID_SUBJECT || "").trim();

  if (apiAccessToken && Buffer.byteLength(apiAccessToken, "utf8") < 32) {
    throw new Error("API_ACCESS_TOKEN должен содержать не менее 32 байт.");
  }
  if (Boolean(pushPublicKey) !== Boolean(pushPrivateKey)) {
    throw new Error("VAPID_PUBLIC_KEY и VAPID_PRIVATE_KEY должны задаваться вместе.");
  }
  if (pushPublicKey) {
    let validSubject = pushSubject.startsWith("mailto:");
    try {
      validSubject ||= new URL(pushSubject).protocol === "https:";
    } catch {
      validSubject = false;
    }
    if (!validSubject) {
      throw new Error("Для Web Push задайте VAPID_SUBJECT в формате mailto: или HTTPS URL.");
    }
  }

  return {
    host: (env.HOST || "127.0.0.1").trim(),
    port: readPositiveInteger(env.PORT, 8787, 65535),
    provider,
    baseUrl,
    model,
    apiKey,
    appOrigin,
    apiAccessToken,
    isApiAuthEnabled: Boolean(apiAccessToken),
    maxRequestBytes: readPositiveInteger(env.MAX_REQUEST_BYTES, 16_384, 65_536),
    requestTimeoutMs: readPositiveInteger(env.AI_TIMEOUT_MS, 25_000, 60_000),
    rateLimitWindowMs: readPositiveInteger(env.RATE_LIMIT_WINDOW_MS, 60_000, 3_600_000),
    rateLimitMaxRequests: readPositiveInteger(env.RATE_LIMIT_MAX_REQUESTS, 20, 500),
    vapidPublicKey: pushPublicKey,
    vapidPrivateKey: pushPrivateKey,
    vapidSubject: pushSubject,
    pushStorePath: (env.PUSH_STORE_PATH || "server/data/push-subscriptions.json").trim(),
    reminderStorePath: (env.REMINDER_STORE_PATH || "server/data/push-reminders.json").trim(),
    isPushConfigured: Boolean(pushPublicKey && pushPrivateKey && pushSubject),
    isAiConfigured: Boolean(apiKey && model && baseUrl)
  };
}
