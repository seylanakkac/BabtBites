// Firebase Cloud Messaging — arka plan (web push) service worker.
// Uygulama kapalı/arka plandayken gelen bildirimleri gösterir.
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDkUu3gjb3bA6nmVhiXoen8Iz0m19RADUo',
  appId: '1:951840473715:web:7a4930eab8cfe7089fa006',
  messagingSenderId: '951840473715',
  projectId: 'babybites-prod-8afe0',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  const n = payload.notification || {};
  self.registration.showNotification(n.title || 'BabyBites', {
    body: n.body || '',
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
  });
});
