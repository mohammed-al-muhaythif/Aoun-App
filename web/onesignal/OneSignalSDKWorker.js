// OneSignal Web SDK v16 service worker.
//
// Kept in /onesignal/ (its own scope) on purpose so it never collides with
// Flutter's root-scope `flutter_service_worker.js`. The matching init in
// web/index.html sets:
//     serviceWorkerParam: { scope: "/onesignal/" }
//     serviceWorkerPath:  "onesignal/OneSignalSDKWorker.js"
//
// Do NOT move this file to the web root.
importScripts("https://cdn.onesignal.com/sdks/web/v16/OneSignalSDK.sw.js");
