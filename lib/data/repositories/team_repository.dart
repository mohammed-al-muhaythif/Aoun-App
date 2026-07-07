import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_client.dart';
import '../models/team.dart';

final teamsProvider = FutureProvider<List<Team>>((ref) async {
  final rows = await sb
      .from('teams')
      .select('*, team_members(user_id, role)')
      .order('created_at', ascending: false);
  return (rows as List)
      .map((m) => Team.fromMap(m as Map<String, dynamic>))
      .toList();
});

class TeamRepository {
  /// Delete a team. RLS enforces who can delete (admin + creator for
  /// non-permanent teams; only app_admin for permanent teams).
  Future<void> deleteTeam(String teamId) =>
      sb.from('teams').delete().eq('id', teamId);

  Future<String> createTeam({
    required String name,
    String? description,
    required List<String> memberIds,
  }) async {
    final uid = sb.auth.currentUser!.id;
    final created = await sb
        .from('teams')
        .insert({
          'name': name,
          'description': description,
          'created_by': uid,
        })
        .select('id')
        .single();
    final teamId = created['id'] as String;

    if (memberIds.isNotEmpty) {
      await sb.from('team_members').insert(
            memberIds.map((u) => {'team_id': teamId, 'user_id': u}).toList(),
          );
    }
    return teamId;
  }
}

final teamRepositoryProvider = Provider((_) => TeamRepository());
