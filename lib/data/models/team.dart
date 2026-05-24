class TeamMemberRef {
  TeamMemberRef({required this.userId, required this.role});
  final String userId;
  final String role; // leader | vice_leader | member
}

class Team {
  Team({
    required this.id,
    required this.name,
    this.description,
    required this.createdBy,
    required this.createdAt,
    this.members = const [],
    this.isPermanent = false,
  });

  final String id;
  final String name;
  final String? description;
  final String createdBy;
  final DateTime createdAt;
  final List<TeamMemberRef> members;
  final bool isPermanent;

  /// Convenience: just the user ids (no roles).
  List<String> get memberIds => members.map((m) => m.userId).toList();

  factory Team.fromMap(Map<String, dynamic> m) => Team(
        id: m['id'] as String,
        name: m['name'] as String,
        description: m['description'] as String?,
        createdBy: m['created_by'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        members: ((m['team_members'] as List?) ?? const [])
            .map((x) => TeamMemberRef(
                  userId: (x as Map<String, dynamic>)['user_id'] as String,
                  role: (x['role'] as String?) ?? 'member',
                ))
            .toList(),
        isPermanent: (m['is_permanent'] as bool?) ?? false,
      );
}
