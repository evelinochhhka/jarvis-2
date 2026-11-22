const CACHE_NAME = "jarvis-2-v4";
const APP_SHELL = [
  "./",
  "./index.html",
  "./manifest.json",
  "./src/app/main.js",
  "./src/features/lists/list-store.js",
  "./src/services/storage/local-store.js",
  "./src/services/api/client.js",
  "./src/features/communications/communications.js",
  "./src/features/communications/push-client.js",
  "./src/features/focus/focus-shortcuts.js"
];

self.addEventListener("install", event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(APP_SHELL))
  );
  self.skipWaiting();
});

self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(
        keys
          .filter(key => key.startsWith("jarvis-2-") && key !== CACHE_NAME)
          .map(key => caches.delete(key))
      )
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", event => {
  const request = event.request;
  if (request.method !== "GET") return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  if (url.pathname.includes("/api/")) return;

  if (request.mode === "navigate") {
    event.respondWith(
      fetch(request)
        .then(response => {
          if (response.ok) {
            const copy = response.clone();
            caches.open(CACHE_NAME).then(cache => cache.put("./index.html", copy));
          }
          return response;
        })
        .catch(async () => {
          const cached = await caches.match("./index.html");
          return cached || Response.error();
        })
    );
    return;
  }

  const isAppAsset = ["script", "style", "image", "font"].includes(request.destination);
  if (!isAppAsset) return;

  event.respondWith(
    caches.match(request).then(async cached => {
      if (cached) return cached;

      const response = await fetch(request);
      if (response.ok && response.type === "basic") {
        const copy = response.clone();
        const cache = await caches.open(CACHE_NAME);
        await cache.put(request, copy);
      }
      return response;
    })
  );
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
      data: { url: typeof payload.url === "string" ? payload.url : "./" }
    };
    await self.registration.showNotification(title, options);
  })());
});

self.addEventListener("notificationclick", event => {
  event.notification.close();
  const target = new URL(event.notification.data?.url || "./", self.location.origin).href;
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
