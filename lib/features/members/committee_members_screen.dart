import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/localization/strings.dart';
import '../../core/permissions/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/task.dart';
import '../../data/models/user_with_roles.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/hours_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/widgets/design_system.dart';
import '../../shared/widgets/empty_state.dart';
import '../hours/hours_unit.dart';

/// Committee head/admin screen — shows all members of one committee with
/// rich stats (this-month hours + task counters). Tap a card to open the
/// member detail screen.
class CommitteeMembersScreen extends ConsumerStatefulWidget {
  const CommitteeMembersScreen({
    super.key,
    required this.committeeId,
    this.committeeName,
  });
  final int committeeId;
  final String? committeeName;

  @override
  ConsumerState<CommitteeMembersScreen> createState() =>
      _CommitteeMembersScreenState();
}

class _CommitteeMembersScreenState
    extends ConsumerState<CommitteeMembersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(allMembersProvider);
    final tasksAsync = ref.watch(myVisibleTasksProvider);
    final meAsync = ref.watch(currentUserProvider);
    final allowed = meAsync.maybeWhen(
      data: (me) => Permissions(me).canManageCommittee(widget.committeeId),
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(widget.committeeName ?? 'إدارة الأعضاء'),
        leading: const _BackButton(),
      ),
      floatingActionButton: allowed
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.purple,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add),
              label: Text('إضافة عضو',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
              onPressed: () => context.push(
                  '/committees/${widget.committeeId}/members/new'
                  '?name=${Uri.encodeComponent(widget.committeeName ?? '')}'),
            )
          : null,
      body: !allowed
          ? const EmptyState(
              message: 'هذه الصفحة لرئيس اللجنة فقط',
              icon: Icons.lock_outline)
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Column(
                  children: [
                    GradientHero(
                      title: widget.committeeName ?? 'أعضاء اللجنة',
                      subtitle: 'إدارة الأعضاء',
                      bottom: _SearchBar(
                        onChanged: (v) => setState(() => _query = v.trim()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: membersAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) =>
                            Center(child: Text('${S.error}: $e')),
                        data: (members) {
                          // Members already in this committee
                          final inCommittee = members
                              .where((m) => m.committees.any(
                                  (c) => c.committeeId == widget.committeeId))
                              .toList();
                          final filtered = _query.isEmpty
                              ? inCommittee
                              : inCommittee
                                  .where((m) =>
                                      m.fullName.contains(_query))
                                  .toList();
                          if (filtered.isEmpty) {
                            return const EmptyState(
                                message: 'لا يوجد أعضاء في هذه اللجنة بعد');
                          }
                          final tasks = tasksAsync.value ?? const <Task>[];
                          return ListView.separated(
                            padding: const EdgeInsets.only(bottom: 90),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) => _MemberRichCard(
                              member: filtered[i],
                              committeeId: widget.committeeId,
                              tasks: tasks,
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

class _BackButton extends StatelessWidget {
  const _BackButton();
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'رجوع',
      onPressed: () =>
          context.canPop() ? context.pop() : context.go('/'),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onChanged});
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        onChanged: onChanged,
        style: GoogleFonts.cairo(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search,
              color: AppColors.textSecondary, size: 20),
          hintText: 'ابحث عن عضو…',
          hintStyle: GoogleFonts.cairo(
              color: AppColors.textSecondary, fontSize: 13),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}

/// One member's rich card: avatar + name + role pill + month hours + task stats.
class _MemberRichCard extends ConsumerWidget {
  const _MemberRichCard({
    required this.member,
    required this.committeeId,
    required this.tasks,
  });
  final UserWithRoles member;
  final int committeeId;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myCommittee = member.committees
        .firstWhere((c) => c.committeeId == committeeId);
    final roleLabel = switch (myCommittee.role) {
      'head' => S.head,
      'vice_head' => S.viceHead,
      _ => S.member,
    };
    final roleColor = switch (myCommittee.role) {
      'head' => AppColors.purple,
      'vice_head' => AppColors.purpleAccent,
      _ => AppColors.statusPending,
    };

    // Tasks assigned to this user (directly).
    final myTasks = tasks
        .where((t) => t.assigneeUserIds.contains(member.id))
        .toList();
    final completed =
        myTasks.where((t) => t.status == TaskStatus.completed).length;
    final inProgress =
        myTasks.where((t) => t.status == TaskStatus.inProgress).length;
    final overdue =
        myTasks.where((t) => t.status == TaskStatus.overdue).length;

    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => context.push(
          '/committees/$committeeId/members/${member.id}'
          '?name=${Uri.encodeComponent(myCommittee.committeeNameAr)}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            InitialAvatar(name: member.fullName, radius: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.fullName,
                      style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(myCommittee.committeeNameAr,
                      style: GoogleFonts.cairo(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Pill(label: roleLabel, color: roleColor),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _MonthHoursTile(userId: member.id),
            ),
            const SizedBox(width: 6),
            _MiniStat(
                label: 'مكتملة',
                value: '$completed',
                color: AppColors.statusCompleted),
            const SizedBox(width: 6),
            _MiniStat(
                label: 'قيد التنفيذ',
                value: '$inProgress',
                color: AppColors.statusInProgress),
            const SizedBox(width: 6),
            _MiniStat(
                label: 'متأخرة',
                value: '$overdue',
                color: AppColors.statusOverdue),
          ]),
        ],
      ),
    );
  }
}

class _MonthHoursTile extends ConsumerWidget {
  const _MonthHoursTile({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(memberHoursSummaryProvider(userId));
    final unit = ref.watch(hoursUnitProvider);
    final v = summary.maybeWhen<int>(
      data: (s) => s.month,
      orElse: () => 0,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text('دقائق الشهر',
              style: GoogleFonts.cairo(
                  fontSize: 10, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(formatVolunteerTime(v, unit),
              style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.purple)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label,
              style: GoogleFonts.cairo(
                  fontSize: 9, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ],
      ),
    );
  }
}
