import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname } from "node:path";

const MAX_REMINDERS = 200;

function reminderError(message, status = 400, code = "INVALID_REMINDER") {
  return Object.assign(new Error(message), { status, code });
}

function validateReminder(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw reminderError("Ожидается объект напоминания.");
  }
  const id = typeof value.id === "string" ? value.id.trim() : "";
  const title = typeof value.title === "string" ? value.title.trim() : "";
  const dueAt = typeof value.dueAt === "string" ? new Date(value.dueAt) : new Date(NaN);
  const timeZone = typeof value.timeZone === "string" ? value.timeZone : "UTC";
  const frequency = ["none", "daily", "weekly", "monthly"].includes(value.repeat?.frequency)
    ? value.repeat.frequency
    : "none";
  const interval = Math.max(1, Math.min(30, Number(value.repeat?.interval) || 1));

  if (!id || id.length > 128 || !title || title.length > 500 || Number.isNaN(dueAt.getTime())) {
    throw reminderError("Напоминанию нужны ID, название и корректная дата/время.");
  }
  try {
    new Intl.DateTimeFormat("en", { timeZone }).format(dueAt);
  } catch {
    throw reminderError("Неизвестный часовой пояс напоминания.");
  }
  return {
    id,
    title,
    body: typeof value.body === "string" ? value.body.trim().slice(0, 500) : "",
    dueAt: dueAt.toISOString(),
    timeZone,
    anchorDay: zonedParts(dueAt, timeZone).day,
    repeat: { frequency, interval },
    updatedAt: new Date().toISOString()
  };
}

function zonedParts(date, timeZone) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23"
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map(part => [part.type, part.value]));
  return {
    year: Number(values.year),
    month: Number(values.month),
    day: Number(values.day),
    hour: Number(values.hour),
    minute: Number(values.minute),
    second: Number(values.second)
  };
}

function fromZonedParts(parts, timeZone) {
  const target = Date.UTC(parts.year, parts.month - 1, parts.day, parts.hour, parts.minute, parts.second);
  let guess = target;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const actual = zonedParts(new Date(guess), timeZone);
    const represented = Date.UTC(
      actual.year, actual.month - 1, actual.day,
      actual.hour, actual.minute, actual.second
    );
    guess += target - represented;
  }
  return new Date(guess);
}

function nextOccurrence(reminder) {
  const parts = zonedParts(new Date(reminder.dueAt), reminder.timeZone);
  const { frequency, interval } = reminder.repeat;
  const local = new Date(Date.UTC(parts.year, parts.month - 1, parts.day, parts.hour, parts.minute, parts.second));

  if (frequency === "daily") {
    local.setUTCDate(local.getUTCDate() + interval);
  } else if (frequency === "weekly") {
    local.setUTCDate(local.getUTCDate() + 7 * interval);
  } else if (frequency === "monthly") {
    const day = reminder.anchorDay || local.getUTCDate();
    local.setUTCDate(1);
    local.setUTCMonth(local.getUTCMonth() + interval);
    const lastDay = new Date(Date.UTC(local.getUTCFullYear(), local.getUTCMonth() + 1, 0)).getUTCDate();
    local.setUTCDate(Math.min(day, lastDay));
  } else {
    return null;
  }

  return fromZonedParts({
    year: local.getUTCFullYear(),
    month: local.getUTCMonth() + 1,
    day: local.getUTCDate(),
    hour: local.getUTCHours(),
    minute: local.getUTCMinutes(),
    second: local.getUTCSeconds()
  }, reminder.timeZone);
}

export function createReminderScheduler(config, pushManager, { startTimer = true } = {}) {
  let writeQueue = Promise.resolve();
  let ticking = false;

  async function readReminders() {
    try {
      const content = await readFile(config.reminderStorePath, "utf8");
      const parsed = JSON.parse(content);
      return Array.isArray(parsed) ? parsed : [];
    } catch (error) {
      if (error.code === "ENOENT") return [];
      throw error;
    }
  }

  async function mutateReminders(mutator) {
    const operation = writeQueue.then(async () => {
      const current = await readReminders();
      const next = mutator(current);
      await mkdir(dirname(config.reminderStorePath), { recursive: true });
      const temporaryPath = `${config.reminderStorePath}.tmp`;
      await writeFile(temporaryPath, JSON.stringify(next, null, 2), { mode: 0o600 });
      await rename(temporaryPath, config.reminderStorePath);
      return next;
    });
    writeQueue = operation.catch(() => {});
    return operation;
  }

  const scheduler = {
    async list() {
      return readReminders();
    },
    async save(input) {
      const reminder = validateReminder(input);
      await mutateReminders(current => {
        const remaining = current.filter(item => item.id !== reminder.id);
        if (remaining.length >= MAX_REMINDERS) {
          throw reminderError("Достигнут лимит серверных напоминаний.", 429, "REMINDER_LIMIT");
        }
        return [...remaining, reminder];
      });
      return reminder;
    },
    async remove(id) {
      if (typeof id !== "string" || !id.trim() || id.length > 128) {
        throw reminderError("Некорректный ID напоминания.");
      }
      await mutateReminders(current => current.filter(item => item.id !== id));
      return { removed: true };
    },
    async tick(now = new Date()) {
      if (ticking) return { processed: 0 };
      ticking = true;
      let processed = 0;
      try {
        if (!pushManager?.configured || await pushManager.count() === 0) {
          return { processed: 0 };
        }
        const due = (await readReminders()).filter(item => Date.parse(item.dueAt) <= now.getTime());
        for (const reminder of due) {
          const result = await pushManager.sendToAll({
            title: "JARVIS",
            body: reminder.body || reminder.title,
            tag: `jarvis-reminder-${reminder.id}`,
            url: "./"
          });
          if (result.sent < 1) continue;

          await mutateReminders(current => current.flatMap(item => {
            if (item.id !== reminder.id || item.dueAt !== reminder.dueAt) return [item];
            const next = nextOccurrence(item);
            if (!next) return [];
            let dueAt = next;
            let skipped = 0;
            while (dueAt.getTime() <= now.getTime() && skipped < 1000) {
              dueAt = nextOccurrence({ ...item, dueAt: dueAt.toISOString() });
              if (!dueAt) return [];
              skipped += 1;
            }
            return [{ ...item, dueAt: dueAt.toISOString(), updatedAt: now.toISOString() }];
          }));
          processed += 1;
        }
        return { processed };
      } finally {
        ticking = false;
      }
    }
  };

  if (startTimer) {
    const timer = setInterval(() => {
      scheduler.tick().catch(() => {});
    }, 15_000);
    timer.unref?.();
  }
  return scheduler;
}
