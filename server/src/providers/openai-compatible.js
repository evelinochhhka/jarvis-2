export class ProviderError extends Error {
  constructor(message, code = "AI_PROVIDER_ERROR", status = 502) {
    super(message);
    this.name = "ProviderError";
    this.code = code;
    this.status = status;
  }
}

export function createOpenAICompatibleProvider(config, fetchImpl = fetch) {
  return {
    async generateReply({ message, language = "auto", preferredLanguage = "ru", history = [] }) {
      if (!config.apiKey) {
        throw new ProviderError("ИИ-провайдер не настроен.", "AI_NOT_CONFIGURED", 503);
      }

      const languageInstruction = language === "ru"
        ? "Отвечайте на русском языке."
        : language === "uk"
          ? "Відповідайте українською мовою."
          : preferredLanguage === "uk"
            ? "Определите язык сообщения. Если пользователь пишет по-украински, отвечайте по-украински; если по-русски, отвечайте по-русски."
            : "Определите язык сообщения. Если пользователь пишет по-русски, отвечайте по-русски; если по-украински, отвечайте по-украински.";

      const systemPrompt = [
        "Вы — персональный цифровой ассистент пользователя.",
        "Общайтесь естественно, уважительно и на «вы».",
        "Поддерживайте русский и украинский языки, сохраняйте язык пользователя и корректно обрабатывайте смешанную речь.",
        "Не утверждайте, что выполнили действие, если сервер не подтвердил его отдельным инструментом.",
        "Не выдумывайте доступ к приложениям, сообщениям, звонкам, файлам, устройствам или системным настройкам.",
        "Если функция недоступна, прямо объясните ограничение и предложите доступный безопасный способ.",
        languageInstruction
      ].join("\n");

      let response;
      try {
        response = await fetchImpl(`${config.baseUrl}/chat/completions`, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${config.apiKey}`,
            "Content-Type": "application/json",
            Accept: "application/json"
          },
          body: JSON.stringify({
            model: config.model,
            messages: [
              { role: "system", content: systemPrompt },
              ...history.slice(-20).map((item) => ({
                role: item.role,
                content: item.content.trim()
              })),
              { role: "user", content: message }
            ],
            max_completion_tokens: 1200
          }),
          signal: AbortSignal.timeout(config.requestTimeoutMs)
        });
      } catch (error) {
        if (error?.name === "TimeoutError" || error?.name === "AbortError") {
          throw new ProviderError("ИИ не ответил вовремя. Повторите запрос позже.", "AI_TIMEOUT", 504);
        }
        throw new ProviderError("Не удалось связаться с ИИ-провайдером.", "AI_UNAVAILABLE", 502);
      }

      if (!response.ok) {
        if (response.status === 429) {
          throw new ProviderError("Достигнут лимит запросов к ИИ. Попробуйте позже.", "AI_RATE_LIMITED", 429);
        }
        throw new ProviderError("ИИ-провайдер отклонил запрос. Проверьте настройки модели.", "AI_UPSTREAM_ERROR", 502);
      }

      const payload = await response.json().catch(() => null);
      const content = payload?.choices?.[0]?.message?.content;
      const text = typeof content === "string"
        ? content.trim()
        : Array.isArray(content)
          ? content.map((part) => typeof part?.text === "string" ? part.text : "").join("").trim()
          : "";

      if (!text) {
        throw new ProviderError("ИИ-провайдер вернул пустой ответ.", "AI_EMPTY_RESPONSE", 502);
      }

      return text;
    }
  };
}
