import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/localization/formatters.dart';
import '../../core/localization/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_with_roles.dart';
import '../../data/models/volunteer_hours.dart';
import '../../data/repositories/hours_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../shared/widgets/design_system.dart';
import '../../shared/widgets/empty_state.dart';

String _fmtHours(double v) =>
    v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

class MemberProfileScreen extends ConsumerWidget {
  const MemberProfileScreen({super.key, required this.memberId});
  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(allMembersProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text(S.memberDirectory)),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${S.error}: $e')),
        data: (members) {
          final m = members.where((x) => x.id == memberId).firstOrNull;
          if (m == null) return const EmptyState(message: S.noData);
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _ProfileHero(member: m),
              const SectionTitle('اللجان'),
              AppCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < m.committees.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, color: AppColors.border),
                      _CommitteeRow(committee: m.committees[i]),
                    ],
                    if (m.committees.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(S.noData,
                            style: GoogleFonts.cairo(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ),
                  ],
                ),
              ),
              const SectionTitle('ساعات التطوع'),
              _MemberHoursStats(userId: m.id),
              const SectionTitle('آخر النشاط'),
              _MemberRecentSessions(userId: m.id),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.member});
  final UserWithRoles member;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.purpleGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              member.fullName.isNotEmpty
                  ? member.fullName.characters.first.toUpperCase()
                  : '?',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 34,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            member.fullName,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            member.primaryRoleLabel,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _MemberHoursStats extends ConsumerWidget {
  const _MemberHoursStats({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(memberHoursSummaryProvider(userId));
    return summaryAsync.when(
      loading: () => const AppCard(
        child: SizedBox(
            height: 80, child: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => AppCard(child: Text('${S.error}: $e')),
      data: (s) {
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
              cell('هذا الأسبوع', s.week, AppColors.statusInProgress),
              const SizedBox(width: 8),
              cell('هذا الشهر', s.month, AppColors.purple),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              cell('هذا العام', s.year, AppColors.statusCompleted),
              const SizedBox(width: 8),
              cell('الإجمالي', s.allTime, AppColors.purpleDark),
            ]),
          ],
        );
      },
    );
  }
}

class _MemberRecentSessions extends ConsumerWidget {
  const _MemberRecentSessions({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(memberHoursProvider(userId));
    return sessionsAsync.when(
      loading: () => const AppCard(
        child: SizedBox(
            height: 80, child: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => AppCard(child: Text('${S.error}: $e')),
      data: (sessions) {
        if (sessions.isEmpty) {
          return AppCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text('لا توجد ساعات مسجّلة',
                  style: GoogleFonts.cairo(
                      color: AppColors.textSecondary, fontSize: 13)),
            ),
          );
        }
        final shown = sessions.take(5).toList();
        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, color: AppColors.border),
                _SessionMiniRow(session: shown[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SessionMiniRow extends StatelessWidget {
  const _SessionMiniRow({required this.session});
  final VolunteerHours session;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        const Icon(Icons.access_time,
            color: AppColors.purple, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(session.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              Text(formatArabicDate(session.activityDate),
                  style: GoogleFonts.cairo(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
        Text('${_fmtHours(session.hours)} س',
            style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.purple)),
      ]),
    );
  }
}

class _CommitteeRow extends StatelessWidget {
  const _CommitteeRow({required this.committee});
  final dynamic committee;

  @override
  Widget build(BuildContext context) {
    final role = switch (committee.role) {
      'head' => S.head,
      'vice_head' => S.viceHead,
      _ => S.member,
    };
    final color = switch (committee.role) {
      'head' => AppColors.statusInProgress,
      'vice_head' => AppColors.purpleAccent,
      _ => AppColors.statusPending,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.groups_2_outlined,
              color: AppColors.purple, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              committee.committeeNameAr,
              style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
          ),
          Pill(label: role, color: color),
        ],
      ),
    );
  }
}
