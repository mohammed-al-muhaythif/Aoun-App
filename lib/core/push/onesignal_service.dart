import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// OneSignal init + per-user external_id binding.
///
/// Web isn't supported by `onesignal_flutter` — calls are no-ops on web
/// so the app still runs cleanly in Chrome during dev.
class OneSignalService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (kIsWeb || _initialized) return;
    final appId = dotenv.env['ONESIGNAL_APP_ID'];
    if (appId == null || appId.isEmpty || appId.startsWith('REPLACE')) {
      // Not configured — skip silently so the app keeps working.
      return;
    }
    OneSignal.Debug.setLogLevel(OSLogLevel.warn);
    OneSignal.initialize(appId);
    // Ask the user for permission on the first cold start.
    await OneSignal.Notifications.requestPermission(true);
    _initialized = true;
  }

  /// Bind the current Supabase user id as OneSignal's external_id so the
  /// send-push function can target `include_aliases.external_id`.
  static Future<void> bindUser(String userId) async {
    if (kIsWeb || !_initialized) return;
    await OneSignal.login(userId);
  }

  static Future<void> unbindUser() async {
    if (kIsWeb || !_initialized) return;
    await OneSignal.logout();
  }
}
