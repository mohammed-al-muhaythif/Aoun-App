import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_client.dart';
import '../models/committee.dart';

final committeesProvider = FutureProvider<List<Committee>>((ref) async {
  final rows = await sb.from('committees').select().order('id');
  return (rows as List)
      .map((m) => Committee.fromMap(m as Map<String, dynamic>))
      .toList();
});

class CommitteeRepository {
  // Quick-add existing user to a committee (no auth user creation).
  Future<void> addMember({
    required String userId,
    required int committeeId,
    String role = 'member',
  }) async {
    await sb.from('committee_memberships').insert({
      'user_id': userId,
      'committee_id': committeeId,
      'role': role,
    });
  }

  // Server-side RPC: create a brand-new user + profile + membership.
  Future<String> addNewMember({
    required String fullName,
    required String universityId,
    required String phone,
    String? major,
    required int committeeId,
    String role = 'member',
  }) async {
    final newId = await sb.rpc('add_member', params: {
      'p_full_name': fullName,
      'p_university_id': universityId,
      'p_phone': phone,
      'p_major': major,
      'p_committee_id': committeeId,
      'p_role': role,
    });
    return newId as String;
  }

  Future<void> updateMemberInfo({
    required String userId,
    required String fullName,
    required String phone,
    required String universityId,
    String? major,
  }) async {
    await sb.rpc('update_member_info', params: {
      'p_user_id': userId,
      'p_full_name': fullName,
      'p_phone': phone,
      'p_university_id': universityId,
      'p_major': major,
    });
  }

  Future<void> changeRole({
    required String userId,
    required int committeeId,
    required String newRole,
  }) async {
    await sb.rpc('change_member_role', params: {
      'p_user_id': userId,
      'p_committee_id': committeeId,
      'p_new_role': newRole,
    });
  }

  Future<void> removeFromCommittee({
    required String userId,
    required int committeeId,
  }) async {
    await sb.rpc('remove_from_committee', params: {
      'p_user_id': userId,
      'p_committee_id': committeeId,
    });
  }

  Future<void> deleteMember(String userId) async {
    await sb.rpc('delete_member', params: {'p_user_id': userId});
  }

  /// God-mode (app_admin only): set or clear the user's club_role.
  /// Pass null to remove the role entirely.
  Future<void> setClubRole({
    required String userId,
    required String? role,
  }) async {
    await sb.rpc('set_club_role', params: {
      'p_user_id': userId,
      'p_role': role,
    });
  }
}

final committeeRepositoryProvider = Provider((_) => CommitteeRepository());
