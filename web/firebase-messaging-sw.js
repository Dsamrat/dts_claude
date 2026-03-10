// firebase-messaging-sw.js
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyA3Sw2Y6k4CuPGBWeybqAQYg83exqPJsLw",
  authDomain: "deliverytrack-80524.firebaseapp.com",
  projectId: "deliverytrack-80524",
  storageBucket: "deliverytrack-80524.firebasestorage.app",
  messagingSenderId: "785699425592",
  appId: "1:785699425592:web:1428b66d1a78e1a9af85cd",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  console.log('[SW] Background message received: ', payload);

  const title = payload.notification?.title || payload.data?.title || 'New Notification';
  const options = {
    body: payload.notification?.body || payload.data?.body || '',
    data: payload.data || {},
  };

  self.registration.showNotification(title, options);
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();

  const screen = event.notification.data?.screen || '';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(clientList => {
      for (const client of clientList) {
        if ('focus' in client) {
          client.postMessage({ screen });
          return client.focus();
        }
      }
      if (clients.openWindow) {
        // Open the app and navigate to the screen
        return clients.openWindow('/#/' + screen);
      }
    })
  );
});
