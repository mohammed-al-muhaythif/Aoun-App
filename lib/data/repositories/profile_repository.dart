import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_client.dart';
import '../models/committee.dart';
import '../models/user_with_roles.dart';

/// All club members with full role info, for the member directory and
/// task-assignment pickers.
final allMembersProvider =
    FutureProvider<List<UserWithRoles>>((ref) async {
  final profiles = await sb
      .from('profiles')
      .select('id, full_name, phone, university_id, major')
      .order('full_name');

  final clubRoles = await sb.from('club_roles').select('user_id, role');
  final clubMap = {
    for (final r in (clubRoles as List))
      r['user_id'] as String: r['role'] as String,
  };

  final memberships = await sb
      .from('committee_memberships')
      .select('user_id, role, committees!inner(id, name_ar, name_en)');

  final cmMap = <String, List<CommitteeMembership>>{};
  for (final m in (memberships as List)) {
    final uid = m['user_id'] as String;
    final c = m['committees'] as Map<String, dynamic>;
    cmMap.putIfAbsent(uid, () => []).add(CommitteeMembership(
          committeeId: c['id'] as int,
          committeeNameAr: c['name_ar'] as String,
          committeeNameEn: c['name_en'] as String,
          role: m['role'] as String,
        ));
  }

  return (profiles as List).map((p) {
    final id = p['id'] as String;
    return UserWithRoles(
      id: id,
      fullName: p['full_name'] as String,
      clubRole: clubMap[id],
      committees: cmMap[id] ?? const [],
      phone: p['phone'] as String?,
      universityId: p['university_id'] as String?,
      major: p['major'] as String?,
    );
  }).toList();
});
