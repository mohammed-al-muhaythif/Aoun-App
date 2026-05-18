import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_client.dart';
import '../models/committee.dart';
import '../models/user_with_roles.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  return sb.auth.onAuthStateChange;
});

final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).when(
        data: (s) => s.session?.user.id,
        loading: () => sb.auth.currentUser?.id,
        error: (_, _) => null,
      );
});

final currentUserProvider =
    FutureProvider<UserWithRoles?>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return null;

  final profile = await sb
      .from('profiles')
      .select('id, full_name')
      .eq('id', uid)
      .maybeSingle();
  if (profile == null) return null;

  final clubRoleRow = await sb
      .from('club_roles')
      .select('role')
      .eq('user_id', uid)
      .maybeSingle();

  final memberships = await sb
      .from('committee_memberships')
      .select('role, committees!inner(id, name_ar, name_en)')
      .eq('user_id', uid);

  final cms = (memberships as List)
      .map((m) {
        final c = m['committees'] as Map<String, dynamic>;
        return CommitteeMembership(
          committeeId: c['id'] as int,
          committeeNameAr: c['name_ar'] as String,
          committeeNameEn: c['name_en'] as String,
          role: m['role'] as String,
        );
      })
      .toList();

  return UserWithRoles(
    id: uid,
    fullName: profile['full_name'] as String,
    clubRole: clubRoleRow?['role'] as String?,
    committees: cms,
  );
});

class AuthRepository {
  /// Normalize a Saudi phone number to 9 digits.
  /// Strips non-digits, country code 966, and leading zero.
  /// Mirrors the SQL helper in 0005_roles_and_permanent_teams.sql.
  static String normalizePhone(String raw) {
    var d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('966')) d = d.substring(3);
    if (d.startsWith('0')) d = d.substring(1);
    return d;
  }

  /// Login with رقم الجوال + الرقم الجامعي.
  /// Looks up the synthetic email via lookup_login_email RPC, then signs in
  /// with the normalized phone as password.
  Future<void> signInWithPhoneAndUniversityId({
    required String phone,
    required String universityId,
  }) async {
    final normPhone = normalizePhone(phone);
    final email = await sb.rpc('lookup_login_email', params: {
      'p_phone': normPhone,
      'p_university_id': universityId.trim(),
    });
    if (email == null || (email is String && email.isEmpty)) {
      throw const AuthException('بيانات الدخول غير صحيحة');
    }
    await sb.auth.signInWithPassword(
      email: email as String,
      password: normPhone,
    );
  }

  /// Login with email + password — mirrors the visible login form.
  /// If the user types just a university id (no `@`), we append the
  /// synthetic `@awan.club` domain automatically. The password is the
  /// member's phone, normalized to 9 digits.
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    var addr = email.trim();
    if (!addr.contains('@')) {
      addr = '$addr@awan.club';
    }
    final pwd = normalizePhone(password);
    await sb.auth.signInWithPassword(
      email: addr,
      password: pwd.isEmpty ? password : pwd,
    );
  }

  Future<void> signOut() => sb.auth.signOut();
}

final authRepositoryProvider = Provider((_) => AuthRepository());
