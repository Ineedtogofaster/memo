// 인터넷이 끊겨도 앱이 열리도록 화면 파일만 저장해 둔다 (메모 데이터는 앱이 따로 보관)
const C = 'memo-v1';
self.addEventListener('install', e => { self.skipWaiting(); e.waitUntil(caches.open(C).then(c => c.addAll(['./', 'index.html', 'config.js', 'manifest.webmanifest', 'icon-192.png']))); });
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));
self.addEventListener('fetch', e => {
  const u = new URL(e.request.url);
  if (e.request.method !== 'GET' || u.pathname.startsWith('/rest/') || u.pathname.startsWith('/auth/') || u.pathname.startsWith('/realtime/')) return; // Supabase API는 건드리지 않음
  e.respondWith(fetch(e.request).then(r => { const copy = r.clone(); caches.open(C).then(c => c.put(e.request, copy)); return r; }).catch(() => caches.match(e.request)));
});
