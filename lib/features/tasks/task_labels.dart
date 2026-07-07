// Shared label helpers for tasks, used by both the task list and the task
// detail screen so the two always agree.

import '../../data/models/task.dart';

/// Committee label for a task:
///   • a single committee's name when the whole task belongs to one
///     committee (assigned to that committee, or every assigned member
///     shares exactly one common committee);
///   • "مهمة عامة" when the assignment spans more than one committee.
///
/// [committees] are `Committee` (with `.id` / `.nameAr`); [members] are
/// `UserWithRoles` (with `.id` / `.committees[].committeeId`). Typed as
/// dynamic to avoid a hard import cycle on the model layer.
String taskCommitteeLabel(
  Task task,
  List<dynamic> committees,
  List<dynamic> members,
) {
  final sets = <Set<int>>[];
  for (final cid in task.assigneeCommitteeIds) {
    sets.add({cid});
  }
  for (final uid in task.assigneeUserIds) {
    final matches = members.where((m) => m.id == uid);
    final m = matches.isEmpty ? null : matches.first;
    final comms = (((m?.committees as List?) ?? const [])
        .map((c) => c.committeeId as int)
        .toSet());
    sets.add(comms);
  }
  if (sets.isEmpty) return 'مهمة عامة';

  var common = sets.first;
  for (final s in sets.skip(1)) {
    common = common.intersection(s);
  }
  if (common.length == 1) {
    final cm = committees.where((c) => c.id == common.first);
    if (cm.isNotEmpty) return cm.first.nameAr as String;
  }
  return 'مهمة عامة';
}

/// Full name of the member who created (and delegated) the task.
String taskCreatorName(Task task, List<dynamic> members) {
  final id = task.createdBy;
  if (id == null) return '—';
  final matches = members.where((m) => m.id == id);
  if (matches.isEmpty) return '—';
  return (matches.first.fullName as String?) ?? '—';
}
