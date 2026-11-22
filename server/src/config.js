const DEFAULT_BASE_URL = "https://api.groq.com/openai/v1";

function readPositiveInteger(value, fallback, maximum) {
  const parsed = Number.parseInt(value || "", 10);
  if (!Number.isInteger(parsed) || parsed < 1) return fallback;
  return Math.min(parsed, maximum);
}

export function loadConfig(env = process.env) {
  const provider = (env.AI_PROVIDER || "groq").trim().toLowerCase();
  const baseUrl = (env.AI_BASE_URL || DEFAULT_BASE_URL).trim().replace(/\/+$/, "");
  const model = (env.AI_MODEL || "openai/gpt-oss-120b").trim();
  const apiKey = (env.AI_API_KEY || "").trim();
  const appOrigin = (env.APP_ORIGIN || "").trim();

  return {
    host: (env.HOST || "127.0.0.1").trim(),
    port: readPositiveInteger(env.PORT, 8787, 65535),
    provider,
    baseUrl,
    model,
    apiKey,
    appOrigin,
    maxRequestBytes: readPositiveInteger(env.MAX_REQUEST_BYTES, 16_384, 65_536),
    requestTimeoutMs: readPositiveInteger(env.AI_TIMEOUT_MS, 25_000, 60_000),
    isAiConfigured: Boolean(apiKey && model && baseUrl)
  };
}
