/* MobSanté Notifications V1 — data-only Web Push handler. */
self.addEventListener('push', (event) => {
  let envelope = {};
  try {
    envelope = event.data ? event.data.json() : {};
  } catch (_) {
    envelope = {};
  }
  const data = envelope.data || envelope;
  if (!data.title || !data.notificationId) return;
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    });
    if (windows.some((client) => client.visibilityState === 'visible')) {
      return;
    }
    if (self.registration.setAppBadge) {
      try {
        await self.registration.setAppBadge();
      } catch (_) {
        // Badging is optional and must never prevent the notification.
      }
    }
    await self.registration.showNotification(data.title, {
      body: data.body || '',
      tag: data.notificationId,
      renotify: false,
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      data: {url: data.url || '/?notification=' + data.notificationId},
    });
  })());
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const target = new URL(event.notification.data?.url || '/', self.location.origin);
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    });
    for (const client of windows) {
      if (new URL(client.url).origin === target.origin) {
        await client.navigate(target.href);
        return client.focus();
      }
    }
    return self.clients.openWindow(target.href);
  })());
});
