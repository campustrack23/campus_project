// web/firebase-messaging-sw.js

// Use compat imports for compatibility with FlutterFire web messaging
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

// REPLACE with your config (public; safe to expose)
// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = {
  apiKey: "AIzaSyBCRbA_eCQoxzqDJDJOxnT_g8fVUPYuMmM",
  authDomain: "campus-7b240.firebaseapp.com",
  projectId: "campus-7b240",
  storageBucket: "campus-7b240.firebasestorage.app",
  messagingSenderId: "853472397092",
  appId: "1:853472397092:web:ccf67962591e1f6c4c55b1",
  measurementId: "G-5ZSKCND26H"
};

// Retrieve messaging
const messaging = firebase.messaging();

// Optional: customize notification click
self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(clientList => {
      for (const client of clientList) {
        if ('focus' in client) return client.focus();
      }
      if (clients.openWindow) return clients.openWindow('/');
    })
  );
});