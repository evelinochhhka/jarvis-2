import { loadConfig } from "./config.js";
import { createAppServer } from "./app.js";
import { createOpenAICompatibleProvider } from "./providers/openai-compatible.js";
import { createPushManager } from "./push.js";
import { createReminderScheduler } from "./reminders.js";

const config = loadConfig();
const provider = createOpenAICompatibleProvider(config);
const pushManager = createPushManager(config);
const reminderScheduler = createReminderScheduler(config, pushManager);
const server = createAppServer({ config, provider, pushManager, reminderScheduler });

server.listen(config.port, config.host, () => {
  process.stdout.write(`JARVIS 2 API listening on http://${config.host}:${config.port}\n`);
});

function shutdown() {
  server.close(() => process.exit(0));
}

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
