import { loadConfig } from "./config.js";
import { createAppServer } from "./app.js";
import { createOpenAICompatibleProvider } from "./providers/openai-compatible.js";
import { createPushManager } from "./push.js";\nimport { createReminderScheduler } from "./reminders.js";

const config = loadConfig();
const provider = createOpenAICompatibleProvider(config);
const pushManager = createPushManager(config);
const server = createAppServer({ config, provider, pushManager });

server.listen(config.port, config.host, () => {
  process.stdout.write(`JARVIS 2 API listening on http://${config.host}:${config.port}\n`);
});

function shutdown() {
  server.close(() => process.exit(0));
}

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
