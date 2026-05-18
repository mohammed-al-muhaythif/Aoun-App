import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/localization/formatters.dart';
import '../../core/localization/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/volunteer_hours.dart';
import '../../data/repositories/hours_repository.dart';
import '../../shared/widgets/design_system.dart';
import '../../shared/widgets/empty_state.dart';

class MyHoursScreen extends ConsumerWidget {
  const MyHoursScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(myHoursProvider);
    final summaryAsync = ref.watch(myHoursSummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('تسجيل ساعات',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        onPressed: () => context.push('/hours/log'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myHoursProvider);
            ref.invalidate(myHoursSummaryProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
            children: [
              GradientHero(
                title: S.myHours,
                subtitle: 'سجل ساعات التطوع',
                bottom: summaryAsync.when(
                  loading: () => const _SummarySkeleton(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (s) => _SummaryGrid(summary: s),
                ),
              ),
              const SectionTitle('السجلات'),
              sessionsAsync.when(
                loading: () => const LoadingSkeleton(),
                error: (e, _) => Text('${S.error}: $e'),
                data: (sessions) {
                  if (sessions.isEmpty) {
                    return const EmptyState(message: S.noData);
                  }
                  return Column(
                    children: [
                      for (final s in sessions) ...[
                        _SessionCard(session: s),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmtHours(double v) =>
    v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});
  final HoursSummary summary;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, double v, Color color) => Expanded(
          child: StatTile(
            label: label,
            value: _fmtHours(v),
            color: color,
            icon: Icons.access_time,
          ),
        );
    return Column(
      children: [
        Row(children: [
          cell('هذا الأسبوع', summary.week, AppColors.statusInProgress),
          const SizedBox(width: 8),
          cell('هذا الشهر', summary.month, AppColors.purple),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          cell('هذا العام', summary.year, AppColors.statusCompleted),
          const SizedBox(width: 8),
          cell('الإجمالي', summary.allTime, AppColors.purpleDark),
        ]),
      ],
    );
  }
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.session});
  final VolunteerHours session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => _confirmDelete(context, ref),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.purpleLight,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.access_time,
                color: AppColors.purple, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.description,
                    style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(formatArabicDate(session.activityDate),
                    style: GoogleFonts.cairo(
                        fontSize: 12, color: AppColors.textSecondary)),
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
              '${_fmtHours(session.hours)} س',
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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف السجل'),
        content: const Text(S.actionCannotUndone),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(S.cancel)),
          TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.statusOverdue),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(S.delete)),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(hoursRepositoryProvider).deleteSession(session.id);
    ref.invalidate(myHoursProvider);
    ref.invalidate(myHoursSummaryProvider);
  }
}
