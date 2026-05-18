import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/localization/strings.dart';
import '../../core/permissions/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/hours_repository.dart';
import '../../shared/widgets/design_system.dart';
import '../../shared/widgets/empty_state.dart';

class HrLeaderboardScreen extends ConsumerStatefulWidget {
  const HrLeaderboardScreen({super.key, this.committeeId, this.title});
  final int? committeeId;
  final String? title;

  @override
  ConsumerState<HrLeaderboardScreen> createState() =>
      _HrLeaderboardScreenState();
}

class _HrLeaderboardScreenState extends ConsumerState<HrLeaderboardScreen> {
  int _periodIdx = 1; // default to "شهر"
  static const _periods = [
    LeaderboardPeriod.week,
    LeaderboardPeriod.month,
    LeaderboardPeriod.year,
    LeaderboardPeriod.allTime,
  ];
  static const _labels = ['أسبوع', 'شهر', 'سنة', 'الكل'];

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(currentUserProvider);
    final allowed = meAsync.maybeWhen(
      data: (me) {
        final p = Permissions(me);
        return widget.committeeId == null
            ? p.canViewLeaderboards
            : p.canViewCommitteeHours(widget.committeeId!);
      },
      orElse: () => false,
    );

    if (!allowed) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(title: const Text('لوحة الشرف')),
        body: const EmptyState(
            message: 'هذه الصفحة متاحة لمسؤولي الموارد البشرية فقط',
            icon: Icons.lock_outline),
      );
    }

    final key = LeaderboardKey(
      period: _periods[_periodIdx],
      committeeId: widget.committeeId,
    );
    final boardAsync = ref.watch(leaderboardProvider(key));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: widget.committeeId != null
          ? AppBar(title: Text(widget.title ?? 'ساعات اللجنة'))
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Column(
            children: [
              GradientHero(
                title: widget.title ??
                    (widget.committeeId == null
                        ? 'لوحة شرف الساعات'
                        : 'ساعات اللجنة'),
                subtitle: widget.committeeId == null
                    ? 'الأعضاء الأكثر تطوعًا'
                    : 'ترتيب أعضاء اللجنة',
                bottom: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: UnderlineTabs(
                    labels: _labels,
                    activeIndex: _periodIdx,
                    onTap: (i) => setState(() => _periodIdx = i),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: boardAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('${S.error}: $e')),
                  data: (rows) {
                    if (rows.isEmpty) {
                      return const EmptyState(
                          message: 'لا توجد ساعات مسجّلة بعد');
                    }
                    return RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(leaderboardProvider(key)),
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) =>
                            _RankRow(rank: i + 1, entry: rows[i]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.entry});
  final int rank;
  final LeaderboardEntry entry;

  Color get _rankColor {
    switch (rank) {
      case 1:
        return const Color(0xFFEAB308); // gold
      case 2:
        return const Color(0xFF94A3B8); // silver
      case 3:
        return const Color(0xFFCD7F32); // bronze
      default:
        return AppColors.purpleAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoursStr =
        '${entry.totalHours.toStringAsFixed(entry.totalHours.truncateToDouble() == entry.totalHours ? 0 : 1)} س';
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      onTap: () => context.push('/members/${entry.userId}'),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _rankColor.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800,
                  color: _rankColor,
                  fontSize: 14),
            ),
          ),
          const SizedBox(width: 10),
          InitialAvatar(name: entry.fullName, radius: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.fullName,
                    style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                if (entry.primaryCommitteeAr != null &&
                    entry.primaryCommitteeAr!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(entry.primaryCommitteeAr!,
                      style: GoogleFonts.cairo(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              hoursStr,
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800,
                  color: AppColors.purple,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
