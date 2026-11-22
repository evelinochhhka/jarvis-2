import test from "node:test";
import assert from "node:assert/strict";
import { createAppServer } from "../server/src/app.js";
import { loadConfig } from "../server/src/config.js";
import { createOpenAICompatibleProvider } from "../server/src/providers/openai-compatible.js";

async function withServer(options, run) {
  const server = createAppServer(options);
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  try {
    await run(`http://127.0.0.1:${address.port}`);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

test("health reports API and AI configuration without exposing secrets", async () => {
  const config = loadConfig({ AI_API_KEY: "private-test-key" });
  await withServer({ config, provider: {} }, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/v1/health`);
    const payload = await response.json();
    assert.equal(response.status, 200);
    assert.equal(payload.status, "ok");
    assert.equal(payload.aiConfigured, true);
    assert.equal(JSON.stringify(payload).includes("private-test-key"), false);
  });
});

test("chat rejects invalid payloads before calling the provider", async () => {
  const config = loadConfig({ AI_API_KEY: "test-key" });
  let called = false;
  const provider = { async generateReply() { called = true; return "Ответ"; } };
  await withServer({ config, provider }, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/v1/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message: " " })
    });
    const payload = await response.json();
    assert.equal(response.status, 400);
    assert.equal(payload.error.code, "INVALID_REQUEST");
    assert.equal(called, false);
  });
});

test("chat returns a real provider response and conversation envelope", async () => {
  const config = loadConfig({ AI_API_KEY: "test-key" });
  const provider = { async generateReply(input) {
    assert.equal(input.message, "Привет");
    assert.equal(input.preferredLanguage, "uk");
    return "Вітаю.";
  } };
  await withServer({ config, provider }, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/v1/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message: " Привет ", preferredLanguage: "uk" })
    });
    const payload = await response.json();
    assert.equal(response.status, 200);
    assert.equal(payload.message.content, "Вітаю.");
    assert.equal(payload.message.role, "assistant");
    assert.ok(payload.conversationId);
  });
});

test("chat does not pretend AI is available when no key is configured", async () => {
  const config = loadConfig({});
  await withServer({ config, provider: {} }, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/v1/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message: "Привет" })
    });
    const payload = await response.json();
    assert.equal(response.status, 503);
    assert.equal(payload.error.code, "AI_NOT_CONFIGURED");
  });
});

test("OpenAI-compatible adapter sends the bilingual system prompt and parses content", async () => {
  let captured;
  const provider = createOpenAICompatibleProvider({
    apiKey: "test-key",
    baseUrl: "https://provider.invalid/v1",
    model: "test-model",
    requestTimeoutMs: 1000
  }, async (url, options) => {
    captured = { url, options, body: JSON.parse(options.body) };
    return new Response(JSON.stringify({
      choices: [{ message: { content: "  Ответ модели  " } }]
    }), { status: 200, headers: { "Content-Type": "application/json" } });
  });

  const reply = await provider.generateReply({
    message: "Привет",
    language: "auto",
    preferredLanguage: "ru"
  });
  assert.equal(reply, "Ответ модели");
  assert.equal(captured.url, "https://provider.invalid/v1/chat/completions");
  assert.equal(captured.body.model, "test-model");
  assert.match(captured.body.messages[0].content, /русский и украинский/);
  assert.equal(captured.options.headers.Authorization, "Bearer test-key");
});

test("provider errors do not expose upstream response bodies", async () => {
  const provider = createOpenAICompatibleProvider({
    apiKey: "test-key",
    baseUrl: "https://provider.invalid/v1",
    model: "test-model",
    requestTimeoutMs: 1000
  }, async () => new Response("secret upstream details", { status: 429 }));

  await assert.rejects(
    provider.generateReply({ message: "Тест" }),
    (error) => error.code === "AI_RATE_LIMITED" && !error.message.includes("secret")
  );
});
