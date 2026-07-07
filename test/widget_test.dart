// Smoke test: ensures the app boots into the login screen.
//
// Doesn't initialize Supabase (which needs network + .env), so it
// only asserts that the AwanApp widget tree builds without crashing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aoun_app/features/auth/login_screen.dart';

void main() {
  testWidgets('Login screen builds', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: LoginScreen(),
          ),
        ),
      ),
    );
    expect(find.text('تسجيل الدخول'), findsWidgets);
  });
}
