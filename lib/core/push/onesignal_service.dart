import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

// Web push goes through window.aoun* shims in web/index.html. On non-web
// targets this resolves to a no-op stub so the app still compiles & runs.
import 'onesignal_web_stub.dart'
    if (dart.library.js_interop) 'onesignal_web_interop.dart' as web_push;

/// OneSignal init + per-user external_id binding.
///
/// Two very different backends:
///  • Mobile / desktop → the `onesignal_flutter` plugin (native SDK).
///  • Web / PWA        → the OneSignal Web SDK v16, loaded in index.html and
///    reached through the `web_push` bridge. The Flutter plugin has no web
///    support, so we must not call it when `kIsWeb`.
class OneSignalService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (kIsWeb) {
      // The Web SDK self-initializes in web/index.html (OneSignal.init()).
      // Binding and the permission prompt happen on demand from Dart.
      _initialized = true;
      return;
    }
    if (_initialized) return;
    final appId = dotenv.env['ONESIGNAL_APP_ID'];
    if (appId == null || appId.isEmpty || appId.startsWith('REPLACE')) {
      // Not configured — skip silently so the app keeps working.
      return;
    }
    OneSignal.Debug.setLogLevel(OSLogLevel.warn);
    OneSignal.initialize(appId);
    // Native platforms may prompt on first launch; iOS native shows its own
    // system dialog. (Web must wait for a button tap — see requestPermission.)
    await OneSignal.Notifications.requestPermission(true);
    _initialized = true;
  }

  /// Ask the user to allow push notifications. Returns true if granted.
  ///
  /// On web this MUST be invoked from a direct user interaction (a button
  /// tap) — iOS Safari 16.4+ rejects permission prompts that aren't tied to a
  /// gesture. Wire it to a "تفعيل الإشعارات" button (see EnablePushButton).
  static Future<bool> requestPermission() async {
    if (kIsWeb) return web_push.requestPermission();
    return OneSignal.Notifications.requestPermission(true);
  }

  /// Whether push can work in this environment at all. On web this is false
  /// for an iOS Safari *tab* — the user must "أضف إلى الشاشة الرئيسية" first.
  static Future<bool> isPushSupported() async {
    if (kIsWeb) return web_push.isSupported();
    return true;
  }

  /// Whether the user has already granted push permission.
  static Future<bool> hasPermission() async {
    if (kIsWeb) return web_push.hasPermission();
    return OneSignal.Notifications.permission;
  }

  /// Bind the current Supabase user id as OneSignal's external_id so the
  /// send-push function can target `include_aliases.external_id`.
  static Future<void> bindUser(String userId) async {
    if (kIsWeb) {
      web_push.login(userId);
      return;
    }
    if (!_initialized) return;
    await OneSignal.login(userId);
  }

  static Future<void> unbindUser() async {
    if (kIsWeb) {
      web_push.logout();
      return;
    }
    if (!_initialized) return;
    await OneSignal.logout();
  }
}
