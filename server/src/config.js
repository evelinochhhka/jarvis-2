const DEFAULT_BASE_URL = "https://openrouter.ai/api/v1";

function readPositiveInteger(value, fallback, maximum) {
  const parsed = Number.parseInt(value || "", 10);
  if (!Number.isInteger(parsed) || parsed < 1) return fallback;
  return Math.min(parsed, maximum);
}

export function loadConfig(env = process.env) {
  const provider = (env.AI_PROVIDER || "openrouter").trim().toLowerCase();
  const baseUrl = (env.AI_BASE_URL || DEFAULT_BASE_URL).trim().replace(/\/+$/, "");
  const model = (env.AI_MODEL || "nvidia/nemotron-3-ultra-550b-a55b:free").trim();
  const apiKey = (env.AI_API_KEY || "").trim();
  const appOrigin = (env.APP_ORIGIN || "").trim();
  const apiAccessToken = (env.API_ACCESS_TOKEN || "").trim();

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
    isAiConfigured: Boolean(apiKey && model && baseUrl)
  };
}
