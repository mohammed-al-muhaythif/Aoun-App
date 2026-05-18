class VolunteerHours {
  VolunteerHours({
    required this.id,
    required this.userId,
    required this.description,
    required this.hours,
    required this.activityDate,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String description;
  final double hours;
  final DateTime activityDate;
  final String? notes;
  final DateTime createdAt;

  factory VolunteerHours.fromMap(Map<String, dynamic> m) => VolunteerHours(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        description: m['description'] as String,
        hours: (m['hours'] as num).toDouble(),
        activityDate: DateTime.parse(m['activity_date'] as String),
        notes: m['notes'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// Aggregated totals for the my-hours summary cards.
class HoursSummary {
  HoursSummary({
    required this.week,
    required this.month,
    required this.year,
    required this.allTime,
  });

  final double week;
  final double month;
  final double year;
  final double allTime;

  factory HoursSummary.fromSessions(List<VolunteerHours> sessions) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday % 7));
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart = DateTime(now.year, 1, 1);
    double w = 0, m = 0, y = 0, all = 0;
    for (final s in sessions) {
      all += s.hours;
      if (!s.activityDate.isBefore(yearStart)) y += s.hours;
      if (!s.activityDate.isBefore(monthStart)) m += s.hours;
      if (!s.activityDate.isBefore(weekStart)) w += s.hours;
    }
    return HoursSummary(week: w, month: m, year: y, allTime: all);
  }
}

/// One row of the `get_hours_leaderboard` RPC — a member with their
/// aggregated hours for a given period (and optional committee filter).
class LeaderboardEntry {
  LeaderboardEntry({
    required this.userId,
    required this.fullName,
    this.primaryCommitteeAr,
    this.primaryRole,
    required this.totalHours,
    required this.sessionCount,
    this.lastActivity,
  });

  final String userId;
  final String fullName;
  final String? primaryCommitteeAr;
  final String? primaryRole;
  final double totalHours;
  final int sessionCount;
  final DateTime? lastActivity;

  factory LeaderboardEntry.fromMap(Map<String, dynamic> m) => LeaderboardEntry(
        userId: m['user_id'] as String,
        fullName: m['full_name'] as String,
        primaryCommitteeAr: m['primary_committee_ar'] as String?,
        primaryRole: m['primary_role'] as String?,
        totalHours: (m['total_hours'] as num?)?.toDouble() ?? 0,
        sessionCount: (m['session_count'] as num?)?.toInt() ?? 0,
        lastActivity: m['last_activity'] == null
            ? null
            : DateTime.parse(m['last_activity'] as String),
      );
}
