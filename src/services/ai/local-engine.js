const MODEL_ID = "Qwen2.5-0.5B-Instruct-q4f16_1-MLC";
const WEBLLM_URL = "https://esm.sh/@mlc-ai/web-llm@0.2.89";

let enginePromise = null;
let engine = null;

export function getLocalAIStatus() {
  return {
    supported: Boolean(globalThis.navigator?.gpu),
    loaded: Boolean(engine),
    loading: Boolean(enginePromise)
  };
}

export async function initializeLocalAI(onProgress = () => {}) {
  if (engine) return engine;
  if (enginePromise) return enginePromise;

  if (!globalThis.navigator?.gpu) {
    throw new Error("В этом браузере нет WebGPU. Локальная модель не сможет запуститься. Откройте JARVIS в актуальном Safari на iPadOS 26 или новее.");
  }

  enginePromise = (async () => {
    onProgress({ progress: 0, text: "Проверяю графический процессор iPad…" });
    const adapter = await navigator.gpu.requestAdapter({ powerPreference: "high-performance" });
    if (!adapter) {
      throw new Error("Safari не предоставил доступ к графическому процессору. Проверьте поддержку WebGPU на устройстве.");
    }

    onProgress({ progress: 0.02, text: "Подключаю движок локального ИИ…" });
    const webllm = await import(WEBLLM_URL);
    const modelRecord = webllm.prebuiltAppConfig.model_list.find(
      (item) => item.model_id === MODEL_ID
    );
    if (!modelRecord) {
      throw new Error("Выбранная модель отсутствует в текущей версии движка WebLLM.");
    }

    const created = await webllm.CreateMLCEngine(MODEL_ID, {
      initProgressCallback: (report) => {
        const progress = Math.max(0, Math.min(1, Number(report.progress) || 0));
        const text = report.text || "Загрузка локальной модели…";
        onProgress({ progress, text });
      },
      logLevel: "WARN"
    });
    engine = created;
    onProgress({ progress: 1, text: "Локальный ИИ готов. Модель сохранена в кэше браузера." });
    return engine;
  })().catch((error) => {
    enginePromise = null;
    engine = null;
    throw new Error(error?.message || "Не удалось запустить локальную модель.");
  });

  return enginePromise;
}

export async function generateLocalReply(history, userMessage) {
  const activeEngine = await initializeLocalAI();
  const messages = [
    {
      role: "system",
      content: "Ты персональный ИИ-помощник JARVIS. Отвечай естественно, содержательно и по делу. Используй русский или украинский язык в соответствии с языком пользователя. Учитывай контекст диалога. Не утверждай, что выполнил действие, если оно фактически не выполнено. Если данных недостаточно, честно обозначь ограничение. Ты работаешь локально на устройстве и не имеешь доступа к интернету, файлам или приложениям, если пользователь явно не передал их содержимое."
    },
    ...(Array.isArray(history) ? history.slice(-12).map((item) => ({
      role: item.role,
      content: item.content
    })) : []),
    { role: "user", content: userMessage }
  ];

  const result = await activeEngine.chat.completions.create({
    messages,
    temperature: 0.55,
    max_tokens: 512,
    stream: false
  });

  const answer = result?.choices?.[0]?.message?.content;
  if (typeof answer !== "string" || !answer.trim()) {
    throw new Error("Локальная модель не вернула ответ. Попробуйте отправить сообщение ещё раз.");
  }
  return answer.trim();
}
