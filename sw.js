// Flüxa Kitchen SW — Etapa 8 (Resiliência)
const CACHE = 'fluxa-kitchen-v8';
const ASSETS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/icon-192.png',
  '/icon-512.png',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2',
  'https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded:opsz,wght,FILL,GRAD@20..48,100..700,0..1,-50..200',
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(ASSETS.filter(a => a.startsWith('http'))))
  );
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  const url = e.request.url;

  // Ignora ABSOLUTAMENTE tudo que não for http/https (extensões, data:, chrome-extension:, etc)
  if (!url || !url.startsWith('http')) return;

  // Supabase: sempre rede, nunca cacheia (evita 406 e problemas de cabeçalho)
  if (url.includes('supabase.co')) return;

  // Navegação (HTML): network-first com fallback
  if (e.request.mode === 'navigate' || url.endsWith('/') || url.endsWith('/index.html')) {
    e.respondWith(
      fetch(e.request)
        .then(res => {
          if (res && res.status === 200) {
            const clone = res.clone();
            caches.open(CACHE).then(c => {
              try { c.put(e.request, clone); } catch (err) { }
            });
          }
          return res;
        })
        .catch(() => caches.match('/index.html'))
    );
    return;
  }

  // Assets estáticos (Fontes, CDNs): cache-first
  if (url.includes('fonts.googleapis') || url.includes('fonts.gstatic') || url.includes('jsdelivr') || url.includes('unpkg')) {
    e.respondWith(
      caches.match(e.request).then(cached => {
        if (cached) return cached;
        return fetch(e.request).then(res => {
          if (res && res.status === 200) {
            const clone = res.clone();
            caches.open(CACHE).then(c => {
              try { c.put(e.request, clone); } catch (err) { }
            });
          }
          return res;
        });
      })
    );
    return;
  }

  // Demais: stale-while-revalidate
  e.respondWith(
    caches.match(e.request).then(cached => {
      const fresh = fetch(e.request).then(res => {
        if (res && res.status === 200) {
          const clone = res.clone();
          caches.open(CACHE).then(c => {
            try { c.put(e.request, clone); } catch (err) { }
          });
        }
        return res;
      }).catch(() => null);
      return cached || fresh;
    })
  );
});

// Mensagens em background
self.addEventListener('push', e => {
  const data = e.data ? e.data.json() : { title: 'Flüxa Kitchen', body: 'Novo pedido!' };
  e.waitUntil(
    self.registration.showNotification(data.title, {
      body: data.body,
      icon: '/icon-192.png',
      badge: '/icon-192.png',
      vibrate: [200, 100, 200]
    })
  );
});

self.addEventListener('notificationclick', e => {
  e.notification.close();
  e.waitUntil(clients.openWindow('/'));
});

