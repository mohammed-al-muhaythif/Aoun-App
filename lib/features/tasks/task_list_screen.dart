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
import '../../data/repositories/committee_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/widgets/design_system.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/notification_bell.dart';
import '../../shared/widgets/status_badge.dart';
import 'task_labels.dart';

/// Task list — same row style as the dashboard's task list section
/// (status dot + title + date | priority pill), with underline tabs
/// matching the mockup.
class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  int _tab = 0; // 0 = all, 1 = completed, 2 = overdue

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(myVisibleTasksProvider);
    final meAsync = ref.watch(currentUserProvider);
    final canCreate = meAsync.maybeWhen(
      data: (me) => Permissions(me).canCreateTask,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(S.tasks),
        actions: const [NotificationBell(), SizedBox(width: 4)],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.purple,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text(S.newTask),
              onPressed: () => context.push('/tasks/new'),
            )
          : null,
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${S.error}: $e')),
        data: (all) {
          final shown = switch (_tab) {
            1 => all.where((t) => t.status == TaskStatus.completed).toList(),
            2 => all.where((t) => t.status == TaskStatus.overdue).toList(),
            _ => all,
          };
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myVisibleTasksProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
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
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: EmptyState(message: S.noData),
                        )
                      else
                        ...shown.map((t) => _TaskRow(task: t)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final committees = ref.watch(committeesProvider).valueOrNull ?? const [];
    final members = ref.watch(allMembersProvider).valueOrNull ?? const [];
    final committee = taskCommitteeLabel(task, committees, members);
    final creator = taskCreatorName(task, members);
    final isGeneral = committee == 'مهمة عامة';

    return InkWell(
      onTap: () => context.push('/tasks/${task.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: StatusDot(color: statusColor(task.status)),
          ),
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
                const SizedBox(height: 6),
                // Committee (or "مهمة عامة") + creator — shown clearly here
                // so members can tell at a glance from outside the task.
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _CommitteeChip(label: committee, general: isGeneral),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.person_outline,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text('بواسطة $creator',
                          style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                    ]),
                  ],
                ),
                if (task.dueDate != null) ...[
                  const SizedBox(height: 4),
                  Text(formatArabicDate(task.dueDate),
                      style: GoogleFonts.cairo(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusBadge(status: task.status),
              const SizedBox(height: 4),
              PriorityBadge(priority: task.priority),
            ],
          ),
        ]),
      ),
    );
  }
}

/// Small tinted chip showing the task's committee, or "مهمة عامة".
class _CommitteeChip extends StatelessWidget {
  const _CommitteeChip({required this.label, required this.general});
  final String label;
  final bool general;

  @override
  Widget build(BuildContext context) {
    final color = general ? AppColors.textSecondary : AppColors.purple;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(general ? Icons.public : Icons.groups_outlined,
            size: 13, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.cairo(
                fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}
