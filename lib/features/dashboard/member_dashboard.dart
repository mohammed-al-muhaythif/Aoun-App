import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/localization/formatters.dart';
import '../../core/localization/strings.dart';
import '../../core/permissions/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/task.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/widgets/design_system.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/notification_bell.dart';
import '../../shared/widgets/status_badge.dart';

/// Mockup #2 in image 2 — "Member Dashboard".
/// Purple bar header with greeting + logout, 2x2 stats grid, progress
/// card, task list with tabs.
class MemberDashboard extends ConsumerStatefulWidget {
  const MemberDashboard({super.key, required this.perms});
  final Permissions perms;

  @override
  ConsumerState<MemberDashboard> createState() => _MemberDashboardState();
}

class _MemberDashboardState extends ConsumerState<MemberDashboard> {
  int _tab = 0; // 0 = all, 1 = completed, 2 = overdue

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(myVisibleTasksProvider);
    final name = widget.perms.me?.fullName ?? '';

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('${S.error}: $e')),
      data: (allTasks) {
        final completed =
            allTasks.where((t) => t.status == TaskStatus.completed).toList();
        final inProgress = allTasks
            .where((t) => t.status == TaskStatus.inProgress)
            .toList();
        final overdue =
            allTasks.where((t) => t.status == TaskStatus.overdue).toList();
        final total = allTasks.length;

        double pct(int n) => total == 0 ? 0 : n / total;

        final shown = switch (_tab) {
          1 => completed,
          2 => overdue,
          _ => allTasks,
        };

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myVisibleTasksProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _GreetingBar(name: name),
              const SizedBox(height: 16),
              // 2x2 stats grid (mockup order, RTL — first item lands on the right)
              Row(children: [
                Expanded(
                    child: StatTile(
                        label: S.completed,
                        value: '${completed.length}',
                        color: AppColors.statusCompleted,
                        icon: Icons.check_circle_outline)),
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
                        value: '${overdue.length}',
                        color: AppColors.statusOverdue,
                        icon: Icons.warning_amber_rounded)),
                const SizedBox(width: 10),
                Expanded(
                    child: StatTile(
                        label: S.inProgress,
                        value: '${inProgress.length}',
                        color: AppColors.statusInProgress,
                        icon: Icons.schedule)),
              ]),

              const SectionTitle(S.taskProgress),
              AppCard(
                child: Column(
                  children: [
                    _ProgressRow(
                        label: S.completed,
                        pct: pct(completed.length),
                        color: AppColors.statusCompleted),
                    _ProgressRow(
                        label: S.inProgress,
                        pct: pct(inProgress.length),
                        color: AppColors.statusInProgress),
                    _ProgressRow(
                        label: S.overdue,
                        pct: pct(overdue.length),
                        color: AppColors.statusOverdue),
                  ],
                ),
              ),

              // Leaderboard is visible to ALL authenticated members.
              // The activity feed remains gated to HR / admin.
              const SectionTitle('أدوات إضافية'),
              const _LeaderboardTile(),
              if (widget.perms.canViewLeaderboards) ...[
                const SizedBox(height: 10),
                const _HoursFeedTile(),
              ],

              const SectionTitle('قائمة المهام'),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    UnderlineTabs(
                      labels: const ['الكل', 'مكتملة', 'متأخرة'],
                      activeIndex: _tab,
                      onTap: (i) => setState(() => _tab = i),
                    ),
                    if (shown.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: EmptyState(message: S.noData),
                      )
                    else
                      ...shown.take(12).map((t) => _TaskListRow(task: t)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GreetingBar extends ConsumerWidget {
  const _GreetingBar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mockup style: flat purple bar (not gradient), greeting on right,
    // small logout pill on left.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.purple,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('مرحباً',
                  style: GoogleFonts.cairo(
                      color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 2),
              Text(name,
                  style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ],
          ),
        ),
        const _WhiteNotificationBell(),
        const SizedBox(width: 8),
        PillButton.outlined(
          label: S.logout,
          onPressed: () async {
            await ref.read(authRepositoryProvider).signOut();
            // Drop ALL cached Riverpod state so the next user doesn't
            // see stale tasks/members/hours from the previous session.
            ref.invalidate(currentUserProvider);
            ref.invalidate(myVisibleTasksProvider);
            if (context.mounted) context.go('/login');
          },
        ),
      ]),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.pct,
    required this.color,
  });
  final String label;
  final double pct;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final shown = (pct * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text(label,
                style: GoogleFonts.cairo(
                    fontSize: 12, color: AppColors.textSecondary)),
            const Spacer(),
            Text('$shown٪',
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct.clamp(0, 1),
              minHeight: 8,
              backgroundColor: AppColors.border,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _WhiteNotificationBell extends StatelessWidget {
  const _WhiteNotificationBell();
  @override
  Widget build(BuildContext context) {
    return Theme(
      // Tint nested icon white on the purple bar.
      data: Theme.of(context).copyWith(
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      child: const NotificationBell(),
    );
  }
}

class _HoursFeedTile extends StatelessWidget {
  const _HoursFeedTile();
  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => context.push('/hours/feed'),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.purple.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.timeline,
              color: AppColors.purple, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('نشاط الساعات',
                  style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              Text('سجل مباشر لساعات كل الأعضاء',
                  style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: AppColors.textSecondary)),
            ],
          ),
        ),
        const Icon(Icons.chevron_left,
            color: AppColors.textSecondary, size: 22),
      ]),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile();
  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => context.push('/leaderboard'),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.statusInProgress.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.emoji_events_outlined,
              color: AppColors.statusInProgress, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('لوحة شرف الساعات',
                  style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              Text('الأعضاء الأكثر تطوعًا حسب الفترة',
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

class _TaskListRow extends StatelessWidget {
  const _TaskListRow({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/tasks/${task.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(children: [
          StatusDot(color: statusColor(task.status)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                if (task.dueDate != null) ...[
                  const SizedBox(height: 2),
                  Text(formatArabicDate(task.dueDate),
                      style: GoogleFonts.cairo(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          PriorityBadge(priority: task.priority),
        ]),
      ),
    );
  }
}
