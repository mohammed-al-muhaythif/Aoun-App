import 'package:flutter/material.dart';

import '../../core/localization/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/task.dart';
import 'design_system.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});
  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TaskStatus.inProgress =>
        (S.statusInProgress, AppColors.statusInProgress),
      TaskStatus.completed => (S.statusCompleted, AppColors.statusCompleted),
      TaskStatus.overdue => (S.statusOverdue, AppColors.statusOverdue),
      TaskStatus.pending => (S.statusPending, AppColors.statusPending),
    };
    return Pill(label: label, color: color);
  }
}

class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, required this.priority});
  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (priority) {
      TaskPriority.high => (S.priorityHigh, AppColors.priorityHigh),
      TaskPriority.medium => (S.priorityMedium, AppColors.priorityMedium),
      TaskPriority.low => (S.priorityLow, AppColors.priorityLow),
    };
    return Pill(label: label, color: color);
  }
}

Color statusColor(TaskStatus s) => switch (s) {
      TaskStatus.completed => AppColors.statusCompleted,
      TaskStatus.inProgress => AppColors.statusInProgress,
      TaskStatus.overdue => AppColors.statusOverdue,
      TaskStatus.pending => AppColors.statusPending,
    };
