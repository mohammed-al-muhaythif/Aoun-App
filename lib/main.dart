import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/push/onesignal_service.dart';
import 'core/supabase/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  await initSupabase();
  await OneSignalService.init();

  // Bind / unbind OneSignal external_id whenever auth state changes.
  sb.auth.onAuthStateChange.listen((state) async {
    final uid = state.session?.user.id;
    if (uid != null) {
      await OneSignalService.bindUser(uid);
    } else {
      await OneSignalService.unbindUser();
    }
  });

  runApp(const ProviderScope(child: AwanApp()));
}
