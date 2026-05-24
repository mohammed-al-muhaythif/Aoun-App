import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/localization/formatters.dart';
import '../../core/localization/strings.dart';
import 'hours_unit.dart';
import '../../core/permissions/permissions.dart';
import '../../core/supabase/supabase_client.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_with_roles.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../shared/widgets/design_system.dart';
import '../../shared/widgets/empty_state.dart';

/// One row of `volunteer_hours` enriched with the logger's name +
/// committee for the activity feed.
class _FeedEntry {
  _FeedEntry({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.committeeAr,
    required this.minutes,
    required this.description,
    this.notes,
    required this.activityDate,
    required this.createdAt,
  });
  final String id;
  final String userId;
  final String fullName;
  final String committeeAr;
  final int minutes;
  final String description;
  final String? notes;
  final DateTime activityDate;
  final DateTime createdAt;
}

/// Realtime stream of every hours entry visible to the caller. RLS
/// already restricts the set: HR / president / committee heads see
/// what they should. Regular members see only their own, but they
/// can't open this screen anyway (permission gated).
final _hoursFeedProvider =
    StreamProvider.autoDispose<List<_FeedEntry>>((ref) {
  final controller = StreamController<List<_FeedEntry>>();
  List<_FeedEntry> current = [];

  Future<void> refresh() async {
    final rows = await sb
        .from('volunteer_hours')
        .select('id, user_id, minutes, description, notes, activity_date, created_at')
        .order('activity_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(500);
    final members = await ref.read(allMembersProvider.future);
    final memById = {for (final m in members) m.id: m};
    current = (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      final u = memById[m['user_id'] as String];
      return _FeedEntry(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        fullName: u?.fullName ?? '—',
        committeeAr: _primaryCommitteeAr(u),
        minutes: (m['minutes'] as num).toInt(),
        description: m['description'] as String,
        notes: m['notes'] as String?,
        activityDate: DateTime.parse(m['activity_date'] as String),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
    }).toList();
    if (!controller.isClosed) controller.add(current);
  }

  refresh();

  final channel = sb
      .channel('hours-feed')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'volunteer_hours',
        callback: (_) => refresh(),
      )
      .subscribe();

  ref.onDispose(() {
    sb.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});

String _primaryCommitteeAr(UserWithRoles? u) {
  if (u == null || u.committees.isEmpty) return 'بدون لجنة';
  // Prefer the leadership committee if any, otherwise first.
  final lead = u.committees.firstWhere(
    (c) => c.role == 'head' || c.role == 'vice_head',
    orElse: () => u.committees.first,
  );
  return lead.committeeNameAr;
}

/// HR/board/admin-only activity feed. Hierarchical:
///   Year ▸ Month ▸ Week ▸ Day ▸ Committee ▸ Entry
class HoursFeedScreen extends ConsumerWidget {
  const HoursFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(currentUserProvider);
    final perms = Permissions(meAsync.value);
    final allowed = perms.canViewLeaderboards;  // HR or admin

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('نشاط الساعات'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: HoursUnitToggle(),
          ),
        ],
      ),
      body: !allowed
          ? const EmptyState(
              message: 'هذه الصفحة لإدارة النادي ولجنة الموارد البشرية فقط',
              icon: Icons.lock_outline)
          : _FeedBody(),
    );
  }
}

class _FeedBody extends ConsumerStatefulWidget {
  @override
  ConsumerState<_FeedBody> createState() => _FeedBodyState();
}

class _FeedBodyState extends ConsumerState<_FeedBody> {
  final Set<String> _collapsed = {};

  HoursUnit get _unit => ref.watch(hoursUnitProvider);

  bool _isCollapsed(String key, {bool defaultCollapsed = false}) {
    if (defaultCollapsed) {
      return !_collapsed.contains('open:$key');
    }
    return _collapsed.contains(key);
  }

  void _toggle(String key, {bool defaultCollapsed = false}) {
    setState(() {
      if (defaultCollapsed) {
        if (_collapsed.contains('open:$key')) {
          _collapsed.remove('open:$key');
        } else {
          _collapsed.add('open:$key');
        }
      } else {
        if (_collapsed.contains(key)) {
          _collapsed.remove(key);
        } else {
          _collapsed.add(key);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(_hoursFeedProvider);
    return feedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('${S.error}: $e')),
      data: (entries) {
        if (entries.isEmpty) {
          return const EmptyState(message: 'لا توجد ساعات مسجّلة بعد');
        }
        // Build hierarchy: year → month → week → day → committee
        final tree = _buildTree(entries);
        final now = DateTime.now();
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            for (final year in tree.keys.toList()..sort((a, b) => b.compareTo(a)))
              _yearSection(tree[year]!, year, now),
          ],
        );
      },
    );
  }

  Widget _yearSection(
      Map<int, Map<int, Map<DateTime, Map<String, List<_FeedEntry>>>>> months,
      int year,
      DateTime now) {
    final yearTotal = _sumOf(months);
    final key = 'y:$year';
    final isCurrent = year == now.year;
    final collapsed = _isCollapsed(key, defaultCollapsed: !isCurrent);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CollapsibleHeader(
            level: 0,
            title: 'سنة $year',
            subtitle: formatVolunteerTime(yearTotal, _unit),
            collapsed: collapsed,
            onTap: () => _toggle(key, defaultCollapsed: !isCurrent),
          ),
          if (!collapsed)
            for (final month
                in months.keys.toList()..sort((a, b) => b.compareTo(a)))
              _monthSection(months[month]!, year, month, now),
        ],
      ),
    );
  }

  Widget _monthSection(
      Map<int, Map<DateTime, Map<String, List<_FeedEntry>>>> weeks,
      int year,
      int month,
      DateTime now) {
    final monthTotal = _sumOfMonth(weeks);
    final key = 'm:$year-$month';
    final isCurrent = year == now.year && month == now.month;
    final collapsed = _isCollapsed(key, defaultCollapsed: !isCurrent);
    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 4, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CollapsibleHeader(
            level: 1,
            title: _arabicMonth(month),
            subtitle: formatVolunteerTime(monthTotal, _unit),
            collapsed: collapsed,
            onTap: () => _toggle(key, defaultCollapsed: !isCurrent),
          ),
          if (!collapsed)
            for (final week in weeks.keys.toList()..sort((a, b) => a.compareTo(b)))
              _weekSection(weeks[week]!, year, month, week),
        ],
      ),
    );
  }

  Widget _weekSection(
      Map<DateTime, Map<String, List<_FeedEntry>>> days,
      int year,
      int month,
      int weekIndex) {
    final weekTotal = _sumOfWeek(days);
    final key = 'w:$year-$month-$weekIndex';
    final collapsed = _isCollapsed(key);
    final label = switch (weekIndex) {
      1 => 'الأسبوع الأول',
      2 => 'الأسبوع الثاني',
      3 => 'الأسبوع الثالث',
      4 => 'الأسبوع الرابع',
      _ => 'الأسبوع الخامس',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 8, left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CollapsibleHeader(
            level: 2,
            title: label,
            subtitle: formatMinutes(weekTotal),
            collapsed: collapsed,
            onTap: () => _toggle(key),
          ),
          if (!collapsed)
            for (final day in days.keys.toList()..sort((a, b) => b.compareTo(a)))
              _daySection(day, days[day]!),
        ],
      ),
    );
  }

  Widget _daySection(DateTime day, Map<String, List<_FeedEntry>> byCommittee) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Text(
              formatArabicDate(day),
              style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
          ),
          for (final committee in byCommittee.keys)
            _committeeBlock(day, committee, byCommittee[committee]!),
        ],
      ),
    );
  }

  Widget _committeeBlock(
      DateTime day, String committee, List<_FeedEntry> entries) {
    final total = entries.fold<int>(0, (a, e) => a + e.minutes);
    final key = 'd:${day.year}-${day.month}-${day.day}|$committee';
    final collapsed = _isCollapsed(key);
    return AppCard(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _toggle(key),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.purpleLight.withValues(alpha: 0.6),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: collapsed
                      ? const Radius.circular(14)
                      : Radius.zero,
                  bottomRight: collapsed
                      ? const Radius.circular(14)
                      : Radius.zero,
                ),
              ),
              child: Row(children: [
                Icon(
                  collapsed
                      ? Icons.keyboard_arrow_left
                      : Icons.keyboard_arrow_down,
                  color: AppColors.purple,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(committee,
                      style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.purple)),
                ),
                Text(formatVolunteerTime(total, _unit),
                    style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.purple)),
              ]),
            ),
          ),
          if (!collapsed)
            for (final e in entries) _entryRow(e),
        ],
      ),
    );
  }

  Widget _entryRow(_FeedEntry e) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InitialAvatar(name: e.fullName, radius: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(e.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                  ),
                  Text(_fmtTime(e.createdAt),
                      style: GoogleFonts.cairo(
                          fontSize: 10,
                          color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 2),
              Text(e.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                      fontSize: 12, color: AppColors.textPrimary)),
              if (e.notes != null && e.notes!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(e.notes!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: AppColors.textSecondary)),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.purple.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(formatVolunteerTime(e.minutes, _unit),
              style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.purple)),
        ),
        if (_canDeleteHours()) ...[
          const SizedBox(width: 4),
          InkWell(
            onTap: () => _confirmDelete(e),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.delete_outline,
                  color: AppColors.statusOverdue, size: 18),
            ),
          ),
        ],
      ]),
    );
  }

  // ─── tree building + aggregation ────────────────────────────────────
  Map<int, Map<int, Map<int, Map<DateTime, Map<String, List<_FeedEntry>>>>>>
      _buildTree(List<_FeedEntry> entries) {
    final t = <int,
        Map<int, Map<int, Map<DateTime, Map<String, List<_FeedEntry>>>>>>{};
    for (final e in entries) {
      final d = DateTime(e.activityDate.year, e.activityDate.month, e.activityDate.day);
      final w = _weekOfMonth(d);
      t.putIfAbsent(d.year, () => {})
          .putIfAbsent(d.month, () => {})
          .putIfAbsent(w, () => {})
          .putIfAbsent(d, () => {})
          .putIfAbsent(e.committeeAr, () => [])
          .add(e);
    }
    return t;
  }

  int _sumOf(Map<int, Map<int, Map<DateTime, Map<String, List<_FeedEntry>>>>> months) {
    int v = 0;
    for (final week in months.values) {
      for (final day in week.values) {
        for (final byC in day.values) {
          for (final list in byC.values) {
            for (final e in list) { v += e.minutes; }
          }
        }
      }
    }
    return v;
  }

  int _sumOfMonth(Map<int, Map<DateTime, Map<String, List<_FeedEntry>>>> weeks) {
    int v = 0;
    for (final day in weeks.values) {
      for (final byC in day.values) {
        for (final list in byC.values) {
          for (final e in list) { v += e.minutes; }
        }
      }
    }
    return v;
  }

  int _sumOfWeek(Map<DateTime, Map<String, List<_FeedEntry>>> days) {
    int v = 0;
    for (final byC in days.values) {
      for (final list in byC.values) {
        for (final e in list) { v += e.minutes; }
      }
    }
    return v;
  }

  int _weekOfMonth(DateTime d) {
    final firstDay = DateTime(d.year, d.month, 1);
    final offset = firstDay.weekday % 7;  // Sun=7→0, Mon=1, ...
    final dayOfMonth = d.day;
    return ((dayOfMonth + offset - 1) ~/ 7) + 1;
  }

  /// Can the current viewer delete arbitrary volunteer_hours rows?
  /// Allowed for: any HR committee member + president/board/leader/admin.
  /// Mirrors the server-side policy in 0017_hr_delete_hours.sql.
  bool _canDeleteHours() {
    final me = ref.read(currentUserProvider).value;
    final p = Permissions(me);
    if (p.isPresident) return true;
    if (me == null) return false;
    return me.committees
        .any((c) => c.committeeNameEn == 'Human Resources');
  }

  Future<void> _confirmDelete(_FeedEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('حذف الساعات', style: GoogleFonts.cairo()),
        content: Text(
          'هل تريد حذف هذه الساعات؟ لا يمكن التراجع عن هذا الإجراء.',
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(S.cancel)),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: AppColors.statusOverdue),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(S.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await sb.from('volunteer_hours').delete().eq('id', e.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الساعات بنجاح')),
      );
      // Realtime listener already refreshes the feed; nothing else to do.
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${S.error}: $err')));
    }
  }

  String _fmtTime(DateTime d) {
    final h = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final m = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour < 12 ? 'ص' : 'م';
    return '$h:$m $ampm';
  }

  String _arabicMonth(int m) => switch (m) {
        1 => 'يناير',
        2 => 'فبراير',
        3 => 'مارس',
        4 => 'أبريل',
        5 => 'مايو',
        6 => 'يونيو',
        7 => 'يوليو',
        8 => 'أغسطس',
        9 => 'سبتمبر',
        10 => 'أكتوبر',
        11 => 'نوفمبر',
        12 => 'ديسمبر',
        _ => '',
      };
}

class _CollapsibleHeader extends StatelessWidget {
  const _CollapsibleHeader({
    required this.level,
    required this.title,
    required this.subtitle,
    required this.collapsed,
    required this.onTap,
  });
  final int level;
  final String title;
  final String subtitle;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.purpleGradient,
      LinearGradient(colors: [
        AppColors.purple.withValues(alpha: 0.85),
        AppColors.purpleAccent.withValues(alpha: 0.7),
      ]),
      LinearGradient(colors: [
        AppColors.purpleLight,
        AppColors.purpleLight,
      ]),
    ];
    final textColor = level == 2 ? AppColors.purple : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          gradient: colors[level],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(
            collapsed
                ? Icons.keyboard_arrow_left
                : Icons.keyboard_arrow_down,
            color: textColor,
            size: 18,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(title,
                style: GoogleFonts.cairo(
                    fontSize: level == 0 ? 16 : (level == 1 ? 14 : 13),
                    fontWeight: FontWeight.w800,
                    color: textColor)),
          ),
          Text(subtitle,
              style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textColor)),
        ]),
      ),
    );
  }
}
