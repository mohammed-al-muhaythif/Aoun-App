import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/localization/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/task.dart';
import '../../data/models/team.dart';
import '../../data/models/user_with_roles.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/team_repository.dart';
import '../../shared/widgets/design_system.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/status_badge.dart';

/// Mockup #4 — Team Dashboard.
/// Gradient purple hero with team name + "فريق" eyebrow,
/// 4 underline tabs (نظرة عامة / المهام / الأعضاء / التقرير),
/// task-progress table, performance bar chart, 3 bottom actions.
class TeamDashboardScreen extends ConsumerStatefulWidget {
  const TeamDashboardScreen({super.key, required this.teamId});
  final String teamId;

  @override
  ConsumerState<TeamDashboardScreen> createState() =>
      _TeamDashboardScreenState();
}

class _TeamDashboardScreenState extends ConsumerState<TeamDashboardScreen> {
  int _tab = 0;
  static const _labels = ['نظرة عامة', 'المهام', 'الأعضاء', 'التقرير'];

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(teamsProvider);
    final tasksAsync = ref.watch(myVisibleTasksProvider);
    final membersAsync = ref.watch(allMembersProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: teamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${S.error}: $e')),
        data: (teams) {
          final team = teams.where((t) => t.id == widget.teamId).firstOrNull;
          if (team == null) return const EmptyState(message: S.noData);

          final members = membersAsync.value ?? const <UserWithRoles>[];
          final teamMembers =
              members.where((m) => team.memberIds.contains(m.id)).toList();
          final allTasks = tasksAsync.value ?? const <Task>[];
          // Team tasks = tasks assigned to any team member
          final teamTasks = allTasks
              .where((t) => t.assigneeUserIds
                  .any((uid) => team.memberIds.contains(uid)))
              .toList();

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              children: [
                _TeamHero(team: team),
                const SizedBox(height: 12),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: UnderlineTabs(
                    labels: _labels,
                    activeIndex: _tab,
                    onTap: (i) => setState(() => _tab = i),
                  ),
                ),
                const SizedBox(height: 12),
                if (_tab == 0) ...[
                  _TasksTable(tasks: teamTasks, members: members),
                  const SizedBox(height: 12),
                  _PerformanceChart(tasks: teamTasks),
                ] else if (_tab == 1) ...[
                  _TasksTable(tasks: teamTasks, members: members),
                ] else if (_tab == 2) ...[
                  _MembersList(members: teamMembers),
                ] else ...[
                  _ReportSection(tasks: teamTasks, members: teamMembers),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TeamHero extends StatelessWidget {
  const _TeamHero({required this.team});
  final Team team;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('فريق',
              style: GoogleFonts.cairo(
                  color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            team.name,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _TasksTable extends StatelessWidget {
  const _TasksTable({required this.tasks, required this.members});
  final List<Task> tasks;
  final List<UserWithRoles> members;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final m in members) m.id: m};
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text('مهام الفريق',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w800, fontSize: 14)),
          ),
          const Divider(height: 1, color: AppColors.border),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: AppColors.surface,
            child: Row(children: [
              _col('الحالة', flex: 2),
              _col('المهمة', flex: 3),
              _col('المسؤول', flex: 2),
              _col('التقدم ٪', flex: 2),
            ]),
          ),
          if (tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: EmptyState(message: S.noData),
            )
          else
            ...tasks.take(8).map((t) {
              final assignee = t.assigneeUserIds.isEmpty
                  ? null
                  : byId[t.assigneeUserIds.first];
              final pct = _progress(t.status);
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.border),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Row(children: [
                        StatusDot(color: statusColor(t.status)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _statusLabel(t.status),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor(t.status)),
                          ),
                        ),
                      ]),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        assignee == null
                            ? '—'
                            : assignee.fullName.split(' ').first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                            fontSize: 12, color: AppColors.textPrimary),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Row(children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 6,
                              backgroundColor: AppColors.border,
                              color: _progressColor(t.status),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('${(pct * 100).round()}٪',
                            style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _progressColor(t.status))),
                      ]),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _col(String s, {required int flex}) => Expanded(
        flex: flex,
        child: Text(s,
            style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary)),
      );

  double _progress(TaskStatus s) => switch (s) {
        TaskStatus.completed => 1.0,
        TaskStatus.inProgress => 0.5,
        TaskStatus.overdue => 0.3,
        TaskStatus.pending => 0.0,
      };

  Color _progressColor(TaskStatus s) => switch (s) {
        TaskStatus.completed => AppColors.statusCompleted,
        TaskStatus.overdue => AppColors.statusOverdue,
        TaskStatus.inProgress => AppColors.statusInProgress,
        TaskStatus.pending => AppColors.statusPending,
      };

  String _statusLabel(TaskStatus s) => switch (s) {
        TaskStatus.completed => S.statusCompleted,
        TaskStatus.inProgress => S.statusInProgress,
        TaskStatus.overdue => S.statusOverdue,
        TaskStatus.pending => S.statusPending,
      };
}

class _PerformanceChart extends StatelessWidget {
  const _PerformanceChart({required this.tasks});
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final values = _buildSeries(tasks);
    final maxV = values.isEmpty
        ? 1
        : values.map((v) => v).reduce((a, b) => a > b ? a : b);
    final labels = ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('أداء الفريق',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final h = maxV == 0 ? 4.0 : (values[i] / maxV) * 90 + 8;
                final isHot = i == 2;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: h,
                          decoration: BoxDecoration(
                            color: isHot
                                ? AppColors.statusInProgress
                                : AppColors.purpleAccent
                                    .withValues(alpha: 0.55),
                            borderRadius:
                                const BorderRadius.vertical(
                                    top: Radius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(labels[i],
                            style: GoogleFonts.cairo(
                                fontSize: 10,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  List<double> _buildSeries(List<Task> tasks) {
    // Distribute completed/in-progress tasks across 7 buckets — a
    // visual indicator only since we don't have per-day metrics.
    final base = List<double>.filled(7, 0);
    for (var i = 0; i < tasks.length; i++) {
      base[i % 7] += 1;
    }
    if (base.every((v) => v == 0)) {
      return [2, 4, 6, 3, 5, 2, 4];
    }
    return base;
  }
}

class _MembersList extends StatelessWidget {
  const _MembersList({required this.members});
  final List<UserWithRoles> members;
  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: members.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(S.noData,
                  style: GoogleFonts.cairo(
                      color: AppColors.textSecondary, fontSize: 13)),
            )
          : Column(
              children: [
                for (var i = 0; i < members.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, color: AppColors.border),
                  InkWell(
                    onTap: () =>
                        context.push('/members/${members[i].id}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(children: [
                        InitialAvatar(
                            name: members[i].fullName, radius: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(members[i].fullName,
                                  style: GoogleFonts.cairo(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                              Text(members[i].primaryRoleLabel,
                                  style: GoogleFonts.cairo(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({required this.tasks, required this.members});
  final List<Task> tasks;
  final List<UserWithRoles> members;

  @override
  Widget build(BuildContext context) {
    final total = tasks.length;
    final completed =
        tasks.where((t) => t.status == TaskStatus.completed).length;
    final overdue =
        tasks.where((t) => t.status == TaskStatus.overdue).length;
    final inProgress =
        tasks.where((t) => t.status == TaskStatus.inProgress).length;
    return Column(
      children: [
        Row(children: [
          Expanded(
              child: StatTile(
                  label: S.completed,
                  value: '$completed',
                  color: AppColors.statusCompleted)),
          const SizedBox(width: 10),
          Expanded(
              child: StatTile(
                  label: S.totalTasks,
                  value: '$total',
                  color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: StatTile(
                  label: S.overdue,
                  value: '$overdue',
                  color: AppColors.statusOverdue)),
          const SizedBox(width: 10),
          Expanded(
              child: StatTile(
                  label: S.inProgress,
                  value: '$inProgress',
                  color: AppColors.statusInProgress)),
        ]),
        const SizedBox(height: 10),
        AppCard(
          child: Row(children: [
            const Icon(Icons.groups_2_outlined,
                color: AppColors.purple, size: 20),
            const SizedBox(width: 8),
            Text('${members.length} عضو',
                style: GoogleFonts.cairo(
                    fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
      ],
    );
  }
}
