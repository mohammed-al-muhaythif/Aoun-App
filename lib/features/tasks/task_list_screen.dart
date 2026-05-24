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

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});
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
