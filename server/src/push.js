import { createHash } from "node:crypto";
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import webPush from "web-push";

const MAX_SUBSCRIPTIONS = 20;

function endpointId(endpoint) {
  return createHash("sha256").update(endpoint).digest("hex");
}

function validateSubscription(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Ожидается объект push-подписки.");
  }
  const endpoint = typeof value.endpoint === "string" ? value.endpoint : "";
  let url;
  try {
    url = new URL(endpoint);
  } catch {
    throw new Error("Некорректный endpoint push-подписки.");
  }
  if (url.protocol !== "https:" || endpoint.length > 2048) {
    throw new Error("Push endpoint должен быть HTTPS-адресом.");
  }
  const p256dh = value.keys?.p256dh;
  const auth = value.keys?.auth;
  if (typeof p256dh !== "string" || typeof auth !== "string"
      || p256dh.length > 256 || auth.length > 128) {
    throw new Error("В push-подписке отсутствуют корректные ключи шифрования.");
  }
  return { endpoint, expirationTime: value.expirationTime ?? null, keys: { p256dh, auth } };
}

export function createPushManager(config, client = webPush) {
  const configured = Boolean(config.isPushConfigured);
  if (configured) {
    client.setVapidDetails(config.vapidSubject, config.vapidPublicKey, config.vapidPrivateKey);
  }

  let writeQueue = Promise.resolve();

  async function readSubscriptions() {
    try {
      const content = await readFile(config.pushStorePath, "utf8");
      const parsed = JSON.parse(content);
      return Array.isArray(parsed) ? parsed : [];
    } catch (error) {
      if (error.code === "ENOENT") return [];
      throw error;
    }
  }

  async function updateSubscriptions(mutator) {
    const operation = writeQueue.then(async () => {
      const current = await readSubscriptions();
      const next = mutator(current);
      await mkdir(dirname(config.pushStorePath), { recursive: true });
      const temporaryPath = `${config.pushStorePath}.tmp`;
      await writeFile(temporaryPath, JSON.stringify(next, null, 2), { mode: 0o600 });
      await rename(temporaryPath, config.pushStorePath);
      return next;
    });
    writeQueue = operation.catch(() => {});
    return operation;
  }

  async function removeByEndpoint(endpoint) {
    const id = endpointId(endpoint);
    await updateSubscriptions(current => current.filter(item => endpointId(item.endpoint) !== id));
  }

  async function send(subscription, payload) {
    if (!configured) return false;
    try {
      await client.sendNotification(subscription, JSON.stringify(payload), { TTL: 60 });
      return true;
    } catch (error) {
      if (error.statusCode === 404 || error.statusCode === 410) {
        await removeByEndpoint(subscription.endpoint);
      }
      return false;
    }
  }

  return {
    get configured() {
      return configured;
    },
    get publicKey() {
      return configured ? config.vapidPublicKey : "";
    },
    async saveSubscription(input) {
      if (!configured) throw new Error("Web Push не настроен на сервере.");
      const subscription = validateSubscription(input);
      await updateSubscriptions(current => {
        const id = endpointId(subscription.endpoint);
        const remaining = current.filter(item => endpointId(item.endpoint) !== id);
        if (remaining.length >= MAX_SUBSCRIPTIONS) {
          throw new Error("Достигнут лимит устройств для push-уведомлений.");
        }
        return [...remaining, subscription];
      });
      const notificationSent = await send(subscription, {
        title: "JARVIS",
        body: "Уведомления JARVIS подключены.",
        tag: "jarvis-push-connected",
        url: "./"
      });
      return { saved: true, notificationSent };
    },
    async removeSubscription(endpoint) {
      if (typeof endpoint !== "string" || !endpoint.startsWith("https://")) {
        throw new Error("Некорректный endpoint push-подписки.");
      }
      await removeByEndpoint(endpoint);
      return { removed: true };
    },
    async sendToAll(payload) {
      if (!configured) return { sent: 0, failed: 0 };
      const subscriptions = await readSubscriptions();
      const results = await Promise.all(subscriptions.map(subscription => send(subscription, payload)));
      return {
        sent: results.filter(Boolean).length,
        failed: results.filter(result => !result).length
      };
    },
    async count() {
      return (await readSubscriptions()).length;
    }
  };
}
