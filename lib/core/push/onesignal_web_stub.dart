// No-op fallback used on non-web targets (mobile/desktop). The real
// implementation lives in `onesignal_web_interop.dart` and is selected via a
// conditional import in `onesignal_service.dart`.

Future<bool> requestPermission() async => false;

void login(String externalId) {}

void logout() {}

Future<bool> hasPermission() async => false;

Future<bool> isSupported() async => false;
