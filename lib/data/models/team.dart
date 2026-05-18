class Team {
  Team({
    required this.id,
    required this.name,
    this.description,
    required this.createdBy,
    required this.createdAt,
    this.memberIds = const [],
    this.isPermanent = false,
  });

  final String id;
  final String name;
  final String? description;
  final String createdBy;
  final DateTime createdAt;
  final List<String> memberIds;
  final bool isPermanent;

  factory Team.fromMap(Map<String, dynamic> m) => Team(
        id: m['id'] as String,
        name: m['name'] as String,
        description: m['description'] as String?,
        createdBy: m['created_by'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        memberIds: ((m['team_members'] as List?) ?? const [])
            .map((x) => x['user_id'] as String)
            .toList(),
        isPermanent: (m['is_permanent'] as bool?) ?? false,
      );
}
