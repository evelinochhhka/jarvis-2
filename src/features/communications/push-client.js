const API_BASE = "/api/v1";

function isStandaloneApp() {
  return globalThis.matchMedia?.("(display-mode: standalone)").matches ||
    globalThis.navigator?.standalone === true;
}

export function getPushCapability() {
  const supported = Boolean(
    globalThis.isSecureContext &&
    "serviceWorker" in navigator &&
    "PushManager" in globalThis &&
    "Notification" in globalThis
  );
  const isIOS = /iphone|ipad|ipod/i.test(navigator.userAgent);
  return {
    supported,
    isIOS,
    standalone: isStandaloneApp(),
    permission: globalThis.Notification?.permission || "unsupported"
  };
}

function decodeApplicationServerKey(value) {
  if (typeof value !== "string" || !value.trim()) {
    throw new Error("Сервер не предоставил публичный ключ push-уведомлений.");
  }
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  const raw = atob(padded);
  return Uint8Array.from(raw, character => character.charCodeAt(0));
}

async function readJson(response) {
  const payload = await response.json().catch(() => null);
  if (!response.ok) {
    throw new Error(
      payload?.error?.message ||
      (response.status === 404
        ? "Сервер уведомлений JARVIS ещё не установлен."
        : "Не удалось связаться с сервером уведомлений.")
    );
  }
  return payload;
}

export async function enablePushNotifications() {
  const capability = getPushCapability();
  if (!capability.supported) {
    throw new Error("Этот браузер или режим запуска не поддерживает push-уведомления JARVIS.");
  }
  if (capability.isIOS && !capability.standalone) {
    throw new Error("На iPhone и iPad откройте JARVIS с иконки на экране «Домой». Push-уведомления для веб-приложений доступны в установленном режиме.");
  }

  const permission = await Notification.requestPermission();
  if (permission !== "granted") {
    throw new Error("Разрешение на уведомления не предоставлено.");
  }

  const registration = await navigator.serviceWorker.ready;
  const keyResponse = await fetch(`${API_BASE}/push/public-key`, {
    headers: { Accept: "application/json" },
    credentials: "same-origin"
  });
  const keyPayload = await readJson(keyResponse);
  const applicationServerKey = decodeApplicationServerKey(keyPayload.publicKey);

  let subscription = await registration.pushManager.getSubscription();
  if (!subscription) {
    subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey
    });
  }

  const saveResponse = await fetch(`${API_BASE}/push/subscriptions`, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json"
    },
    credentials: "same-origin",
    body: JSON.stringify(subscription)
  });
  await readJson(saveResponse);
  return subscription;
}

export async function disablePushNotifications() {
  const registration = await navigator.serviceWorker.ready;
  const subscription = await registration.pushManager.getSubscription();
  if (!subscription) return false;

  const response = await fetch(`${API_BASE}/push/subscriptions`, {
    method: "DELETE",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json"
    },
    credentials: "same-origin",
    body: JSON.stringify({ endpoint: subscription.endpoint })
  });
  await readJson(response);
  return subscription.unsubscribe();
}
