const CACHE_NAME = "jarvis-2-app-v6";
const APP_SHELL = [
  "./index.html",
  "./manifest.json",
  "./icon.svg",
  "./style.css",
  "./src/app/main.js",
  "./src/features/lists/list-store.js",
  "./src/features/files/files.js",
  "./src/features/files/file-store.js",
  "./src/features/communications/communications.js",
  "./src/features/communications/push-client.js",
  "./src/features/focus/focus-shortcuts.js",
  "./src/services/storage/local-store.js",
  "./src/services/api/client.js",
  "./src/services/ai/local-engine.js"
];

self.addEventListener("install", event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    await cache.addAll(APP_SHELL);
    await self.skipWaiting();
  })());
});

self.addEventListener("activate", event => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(
      keys
        .filter(key => key.startsWith("jarvis-2-") && key !== CACHE_NAME)
        .map(key => caches.delete(key))
    );
    await self.clients.claim();
  })());
});

self.addEventListener("fetch", event => {
  const request = event.request;
  if (request.method !== "GET") return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin || url.pathname.includes("/api/")) return;

  if (request.mode === "navigate") {
    event.respondWith((async () => {
      try {
        const response = await fetch(request);
        if (response.ok) {
          const cache = await caches.open(CACHE_NAME);
          await cache.put("./index.html", response.clone());
        }
        return response;
      } catch {
        return (await caches.match("./index.html")) || Response.error();
      }
    })());
    return;
  }

  event.respondWith((async () => {
    const cached = await caches.match(request);
    if (cached) return cached;

    try {
      const response = await fetch(request);
      if (response.ok && response.type === "basic") {
        const cache = await caches.open(CACHE_NAME);
        await cache.put(request, response.clone());
      }
      return response;
    } catch {
      return Response.error();
    }
  })());
});

self.addEventListener("push", event => {
  event.waitUntil((async () => {
    let payload = {};
    try {
      payload = event.data ? event.data.json() : {};
    } catch {
      payload = { body: event.data?.text() || "Новое уведомление JARVIS." };
    }
    const title = typeof payload.title === "string" ? payload.title : "JARVIS";
    const options = {
      body: typeof payload.body === "string" ? payload.body : "У вас новое уведомление.",
      tag: typeof payload.tag === "string" ? payload.tag : "jarvis-notification",
      data: { url: typeof payload.url === "string" ? payload.url : "./index.html" }
    };
    await self.registration.showNotification(title, options);
  })());
});

self.addEventListener("notificationclick", event => {
  event.notification.close();
  const target = new URL(event.notification.data?.url || "./index.html", self.location.origin).href;
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: "window", includeUncontrolled: true });
    for (const client of windows) {
      if ("focus" in client) {
        await client.focus();
        if ("navigate" in client) await client.navigate(target);
        return;
      }
    }
    if (self.clients.openWindow) await self.clients.openWindow(target);
  })());
});
