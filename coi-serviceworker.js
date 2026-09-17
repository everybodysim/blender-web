/* Minimal COOP/COEP service worker for static hosting. */
const COEP = 'require-corp';
const COOP = 'same-origin';
const CORP = 'cross-origin';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));
self.addEventListener('fetch', event => {
  if (event.request.cache === 'only-if-cached' && event.request.mode !== 'same-origin') return;
  event.respondWith((async () => {
    const response = await fetch(event.request);
    const headers = new Headers(response.headers);
    headers.set('Cross-Origin-Embedder-Policy', COEP);
    headers.set('Cross-Origin-Opener-Policy', COOP);
    headers.set('Cross-Origin-Resource-Policy', CORP);
    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers
    });
  })());
});
