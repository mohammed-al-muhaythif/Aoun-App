// Web implementation of the OneSignal bridge. Talks to the `window.aoun*`
// helper functions defined in web/index.html via `dart:js_interop`.
//
// This file is only ever compiled for web (selected by the conditional import
// in `onesignal_service.dart` on `dart.library.js_interop`).

import 'dart:js_interop';

@JS('aounRequestPushPermission')
external JSPromise<JSBoolean> _requestPermission();

@JS('aounOneSignalLogin')
external void _login(JSString externalId);

@JS('aounOneSignalLogout')
external void _logout();

@JS('aounPushPermission')
external JSPromise<JSBoolean> _permission();

@JS('aounPushSupported')
external JSPromise<JSBoolean> _supported();

/// Prompt for push permission (must be called from a user gesture on iOS).
Future<bool> requestPermission() async {
  final result = await _requestPermission().toDart;
  return result.toDart;
}

/// Bind the Supabase user id as OneSignal's external_id.
void login(String externalId) => _login(externalId.toJS);

/// Clear the external_id binding on sign-out.
void logout() => _logout();

/// Whether the user has already granted push permission.
Future<bool> hasPermission() async => (await _permission().toDart).toDart;

/// Whether web push can work in this context at all.
Future<bool> isSupported() async => (await _supported().toDart).toDart;
