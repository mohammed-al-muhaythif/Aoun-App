import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_client.dart';
import '../models/volunteer_hours.dart';
export '../models/volunteer_hours.dart' show LeaderboardEntry;
import 'auth_repository.dart';

/// All hours sessions visible to the current user (RLS-filtered server-side).
/// For a plain member: just their own.
/// For HR / president: everyone.
/// For committee_head: own committee members.
final myHoursProvider = FutureProvider<List<VolunteerHours>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return [];
  final rows = await sb
      .from('volunteer_hours')
      .select()
      .eq('user_id', uid)
      .order('activity_date', ascending: false);
  return (rows as List)
      .map((m) => VolunteerHours.fromMap(m as Map<String, dynamic>))
      .toList();
});

/// Roll-up of my-hours into week / month / year / all-time totals.
final myHoursSummaryProvider = FutureProvider<HoursSummary>((ref) async {
  final sessions = await ref.watch(myHoursProvider.future);
  return HoursSummary.fromSessions(sessions);
});

/// Hours sessions of any specific member — RLS gates visibility:
/// own → always; head of their committee → yes; HR/president → yes; else empty.
final memberHoursProvider =
    FutureProvider.family<List<VolunteerHours>, String>((ref, userId) async {
  final rows = await sb
      .from('volunteer_hours')
      .select()
      .eq('user_id', userId)
      .order('activity_date', ascending: false);
  return (rows as List)
      .map((m) => VolunteerHours.fromMap(m as Map<String, dynamic>))
      .toList();
});

/// Roll-up of member's hours into the same week/month/year/all buckets.
final memberHoursSummaryProvider =
    FutureProvider.family<HoursSummary, String>((ref, userId) async {
  final sessions = await ref.watch(memberHoursProvider(userId).future);
  return HoursSummary.fromSessions(sessions);
});

enum LeaderboardPeriod { week, month, year, allTime }

class LeaderboardKey {
  const LeaderboardKey({required this.period, this.committeeId, this.limit = 50});
  final LeaderboardPeriod period;
  final int? committeeId;
  final int limit;

  @override
  bool operator ==(Object other) =>
      other is LeaderboardKey &&
      other.period == period &&
      other.committeeId == committeeId &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(period, committeeId, limit);
}

/// Aggregated leaderboard entries from the `get_hours_leaderboard` SQL function.
final leaderboardProvider =
    FutureProvider.family<List<LeaderboardEntry>, LeaderboardKey>((ref, key) async {
  return ref.read(hoursRepositoryProvider).getLeaderboard(
        period: key.period,
        committeeId: key.committeeId,
        limit: key.limit,
      );
});

class HoursRepository {
  /// Insert a new entry. `minutes` is the raw number of minutes (int, > 0).
  Future<void> logHours({
    required String description,
    required int minutes,
    required DateTime activityDate,
    String? notes,
  }) async {
    final uid = sb.auth.currentUser!.id;
    await sb.from('volunteer_hours').insert({
      'user_id': uid,
      'description': description,
      'minutes': minutes,
      'activity_date':
          activityDate.toIso8601String().substring(0, 10),
      'notes': notes,
    });
  }

  Future<void> deleteSession(String id) =>
      sb.from('volunteer_hours').delete().eq('id', id);

  Future<List<LeaderboardEntry>> getLeaderboard({
    required LeaderboardPeriod period,
    int? committeeId,
    int limit = 50,
  }) async {
    final range = _rangeFor(period);
    final rows = await sb.rpc('get_hours_leaderboard', params: {
      'p_start': range.start?.toIso8601String().substring(0, 10),
      'p_end': range.end?.toIso8601String().substring(0, 10),
      'p_committee_id': committeeId,
      'p_limit': limit,
    });
    return (rows as List)
        .map((m) => LeaderboardEntry.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  _DateRange _rangeFor(LeaderboardPeriod p) {
    final now = DateTime.now();
    switch (p) {
      case LeaderboardPeriod.week:
        final weekStart = now.subtract(Duration(days: now.weekday % 7));
        return _DateRange(
            start: DateTime(weekStart.year, weekStart.month, weekStart.day),
            end: now);
      case LeaderboardPeriod.month:
        return _DateRange(start: DateTime(now.year, now.month, 1), end: now);
      case LeaderboardPeriod.year:
        return _DateRange(start: DateTime(now.year, 1, 1), end: now);
      case LeaderboardPeriod.allTime:
        return const _DateRange(start: null, end: null);
    }
  }
}

class _DateRange {
  const _DateRange({required this.start, required this.end});
  final DateTime? start;
  final DateTime? end;
}

final hoursRepositoryProvider = Provider((_) => HoursRepository());
