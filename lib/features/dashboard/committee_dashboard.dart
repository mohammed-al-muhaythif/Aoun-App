import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/localization/formatters.dart';
import '../../core/localization/strings.dart';
import '../../core/permissions/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/committee.dart';
import '../../data/models/task.dart';
import '../../data/models/user_with_roles.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/widgets/design_system.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/notification_bell.dart';
import '../../shared/widgets/status_badge.dart';

/// Mockup #3 in image 2 — "Committee Head Dashboard".
/// Purple gradient hero card with committee name + 3 stat counters,
/// tabs (نظرة عامة / المهام / الأعضاء), stats table, members grid.
class CommitteeDashboard extends ConsumerStatefulWidget {
  const CommitteeDashboard({
    super.key,
    required this.perms,
    required this.committee,
  });

  final Permissions perms;
  final CommitteeMembership committee; // the head's own committee

  @override
  ConsumerState<CommitteeDashboard> createState() =>
      _CommitteeDashboardState();
}

class _CommitteeDashboardState extends ConsumerState<CommitteeDashboard> {
  int _tab = 0; // 0 = overview, 1 = tasks, 2 = members

  @override
  Widget build(BuildContext context) {
    final cId = widget.committee.committeeId;
    final tasksAsync = ref.watch(myVisibleTasksProvider);
    final membersAsync = ref.watch(allMembersProvider);

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('${S.error}: $e')),
      data: (allTasks) {
        // committee tasks = tasks assigned to this committee or to one
        // of its members.
        final members = membersAsync.value ?? const <UserWithRoles>[];
        final committeeMemberIds = members
            .where((m) =>
                m.committees.any((c) => c.committeeId == cId))
            .map((m) => m.id)
            .toSet();

        final cTasks = allTasks.where((t) {
          if (t.assigneeCommitteeIds.contains(cId)) return true;
          return t.assigneeUserIds.any(committeeMemberIds.contains);
        }).toList();

        final completed =
            cTasks.where((t) => t.status == TaskStatus.completed).length;
        final overdue =
            cTasks.where((t) => t.status == TaskStatus.overdue).length;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myVisibleTasksProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              GradientHero(
                title: widget.committee.committeeNameAr,
                subtitle: widget.perms.me?.primaryRoleLabel,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Theme(
                      data: Theme.of(context).copyWith(
                        iconTheme: const IconThemeData(color: Colors.white),
                      ),
                      child: const NotificationBell(),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      tooltip: S.logout,
                      onPressed: () async {
                        await ref
                            .read(authRepositoryProvider)
                            .signOut();
                        ref.invalidate(currentUserProvider);
                        ref.invalidate(myVisibleTasksProvider);
                        if (context.mounted) context.go('/login');
                      },
                    ),
                  ],
                ),
                bottom: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // RTL order: rightmost first → overdue, completed, total
                    _HeroStat(
                        label: 'المتأخرة',
                        value: '$overdue',
                        color: AppColors.statusOverdue),
                    _HeroStat(
                        label: 'مكتملة',
                        value: '$completed',
                        color: AppColors.statusCompleted),
                    _HeroStat(
                        label: 'المهام',
                        value: '${cTasks.length}',
                        color: AppColors.purpleAccent),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                padding: EdgeInsets.zero,
                child: UnderlineTabs(
                  labels: const ['نظرة عامة', 'المهام', 'الأعضاء'],
                  activeIndex: _tab,
                  onTap: (i) => setState(() => _tab = i),
                ),
              ),
              const SizedBox(height: 12),
              if (_tab == 0) ...[
                if (widget.perms.canCreateTask) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: GoogleFonts.cairo(
                          fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('إضافة مهمة جديدة'),
                    onPressed: () => context.push('/tasks/new'),
                  ),
                  const SizedBox(height: 12),
                ],
                _CommitteeStatsTable(tasks: cTasks, members: members),
                const SizedBox(height: 12),
                if (widget.perms.canViewCommitteeHours(cId)) ...[
                  _HoursAccessTile(
                    title: 'ساعات أعضاء اللجنة',
                    subtitle: 'عرض ترتيب الأعضاء حسب الساعات',
                    icon: Icons.access_time,
                    color: AppColors.purple,
                    onTap: () => context.push(
                        '/committees/$cId/hours?name=${Uri.encodeComponent(widget.committee.committeeNameAr)}'),
                  ),
                  const SizedBox(height: 10),
                ],
                // Leaderboard visible to ALL members (no permission gate).
                _HoursAccessTile(
                  title: 'لوحة شرف الساعات',
                  subtitle: 'الأعضاء الأكثر تطوعًا',
                  icon: Icons.emoji_events_outlined,
                  color: AppColors.statusInProgress,
                  onTap: () => context.push('/leaderboard'),
                ),
                const SizedBox(height: 10),
                // Activity feed remains HR / admin only.
                if (widget.perms.canViewLeaderboards) ...[
                  _HoursAccessTile(
                    title: 'نشاط الساعات',
                    subtitle: 'سجل مباشر لكل الأعضاء',
                    icon: Icons.timeline,
                    color: AppColors.purple,
                    onTap: () => context.push('/hours/feed'),
                  ),
                  const SizedBox(height: 10),
                ],
                _MembersGrid(
                  committeeId: cId,
                  members: members
                      .where((m) => m.committees
                          .any((c) => c.committeeId == cId))
                      .toList(),
                  canAdd: widget.perms.canManageCommittee(cId),
                ),
              ] else if (_tab == 1) ...[
                if (cTasks.isEmpty)
                  const EmptyState(message: S.noData)
                else
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: cTasks.map((t) => _CommitteeTaskRow(t: t)).toList(),
                    ),
                  ),
              ] else ...[
                _MembersGrid(
                  committeeId: cId,
                  members: members
                      .where((m) => m.committees
                          .any((c) => c.committeeId == cId))
                      .toList(),
                  canAdd: widget.perms.canManageCommittee(cId),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.cairo(
                fontSize: 24, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            style: GoogleFonts.cairo(
                fontSize: 11, color: Colors.white70)),
      ],
    );
  }
}

class _CommitteeStatsTable extends StatelessWidget {
  const _CommitteeStatsTable({required this.tasks, required this.members});
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
            child: Text('إحصائيات اللجنة',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w800, fontSize: 14)),
          ),
          const Divider(height: 1),
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: AppColors.surface,
            child: Row(children: [
              _col('المهمة', flex: 3),
              _col('الحالة', flex: 2),
              _col('المسؤول', flex: 2),
              _col('الموعد', flex: 2),
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
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.border),
                  ),
                ),
                child: Row(children: [
                  _val(t.title, flex: 3, weight: FontWeight.w600),
                  Expanded(
                      flex: 2,
                      child: Align(
                          alignment: Alignment.centerRight,
                          child: StatusBadge(status: t.status))),
                  _val(assignee?.fullName ?? '—', flex: 2),
                  _val(t.dueDate == null ? '—' : formatArabicDate(t.dueDate),
                      flex: 2,
                      color: t.status == TaskStatus.overdue
                          ? AppColors.statusOverdue
                          : null),
                ]),
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

  Widget _val(String s, {required int flex, FontWeight? weight, Color? color}) =>
      Expanded(
        flex: flex,
        child: Text(
          s,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: weight ?? FontWeight.w500,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      );
}

class _MembersGrid extends StatelessWidget {
  const _MembersGrid({
    required this.committeeId,
    required this.members,
    required this.canAdd,
  });
  final int committeeId;
  final List<UserWithRoles> members;
  final bool canAdd;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text('أعضاء اللجنة',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w800, fontSize: 14)),
            const Spacer(),
            if (canAdd)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  textStyle: GoogleFonts.cairo(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
                onPressed: () => context.push(
                    '/committees/$committeeId/members'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('إدارة الأعضاء'),
              ),
          ]),
          const SizedBox(height: 12),
          if (members.isEmpty)
            const EmptyState(message: S.noData)
          else
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: members
                  .take(9)
                  .map((m) => SizedBox(
                        width: 72,
                        child: Column(
                          children: [
                            InitialAvatar(name: m.fullName, radius: 28),
                            const SizedBox(height: 6),
                            Text(
                              m.fullName.split(' ').first,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                            Text(
                              _roleLabel(m, committeeId),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                  fontSize: 10,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  String _roleLabel(UserWithRoles u, int cid) {
    final r = u.committees.firstWhere(
      (c) => c.committeeId == cid,
      orElse: () => u.committees.first,
    );
    return switch (r.role) {
      'head' => S.head,
      'vice_head' => S.viceHead,
      _ => S.member,
    };
  }
}

class _HoursAccessTile extends StatelessWidget {
  const _HoursAccessTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              Text(subtitle,
                  style: GoogleFonts.cairo(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        const Icon(Icons.chevron_left,
            color: AppColors.textSecondary, size: 22),
      ]),
    );
  }
}

class _CommitteeTaskRow extends StatelessWidget {
  const _CommitteeTaskRow({required this.t});
  final Task t;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/tasks/${t.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(children: [
          StatusDot(color: statusColor(t.status)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          StatusBadge(status: t.status),
          const SizedBox(width: 6),
          PriorityBadge(priority: t.priority),
        ]),
      ),
    );
  }
}
