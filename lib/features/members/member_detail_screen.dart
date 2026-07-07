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
import '../../data/repositories/committee_repository.dart';
import '../../data/repositories/hours_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/widgets/design_system.dart';
import '../../shared/widgets/empty_state.dart';
import '../hours/hours_unit.dart';

/// Member detail (committee-scoped). Shows full info + hours + tasks
/// + action buttons gated by the caller's permissions.
class MemberDetailScreen extends ConsumerWidget {
  const MemberDetailScreen({
    super.key,
    required this.committeeId,
    required this.memberId,
    this.committeeName,
  });
  final int committeeId;
  final String memberId;
  final String? committeeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(allMembersProvider);
    final tasksAsync = ref.watch(myVisibleTasksProvider);
    final meAsync = ref.watch(currentUserProvider);
    final perms = Permissions(meAsync.value);
    final isHrOrAdmin = perms.isPresident || perms.isHrHead;
    final canManageThisCommittee = perms.canManageCommittee(committeeId);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('ملف العضو'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${S.error}: $e')),
        data: (members) {
          final m = members.where((x) => x.id == memberId).firstOrNull;
          if (m == null) return const EmptyState(message: S.noData);
          final inCommittee = m.committees
              .firstWhere((c) => c.committeeId == committeeId,
                  orElse: () => m.committees.isEmpty
                      ? m.committees.first
                      : m.committees.first);
          final tasks = tasksAsync.value ?? const <Task>[];
          final myTasks =
              tasks.where((t) => t.assigneeUserIds.contains(m.id)).toList();
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _Hero(member: m, roleInCommittee: inCommittee.role),
              const SectionTitle('المعلومات الشخصية'),
              AppCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
                child: Column(children: [
                  InfoRow(label: 'الاسم', value: m.fullName),
                  InfoRow(label: 'رقم الجوال', value: m.phone ?? '—'),
                  InfoRow(
                      label: 'الرقم الجامعي', value: m.universityId ?? '—'),
                  InfoRow(label: 'التخصص', value: m.major ?? '—'),
                ]),
              ),
              const SectionTitle('اللجان'),
              AppCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < m.committees.length; i++) ...[
                      if (i > 0)
                        const Divider(
                            height: 1, color: AppColors.border),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(children: [
                          const Icon(Icons.groups_2_outlined,
                              color: AppColors.purple, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(m.committees[i].committeeNameAr,
                                  style: GoogleFonts.cairo(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700))),
                          Pill(
                              label: switch (m.committees[i].role) {
                                'head' => S.head,
                                'vice_head' => S.viceHead,
                                _ => S.member,
                              },
                              color: switch (m.committees[i].role) {
                                'head' => AppColors.purple,
                                'vice_head' => AppColors.purpleAccent,
                                _ => AppColors.statusPending,
                              }),
                        ]),
                      ),
                    ],
                  ],
                ),
              ),
              const SectionTitle('ساعات التطوع'),
              _HoursStats(userId: m.id),
              const SectionTitle('المهام'),
              _TaskStats(tasks: myTasks),
              if (canManageThisCommittee) ...[
                const SectionTitle('إجراءات'),
                _ActionsCard(
                  member: m,
                  committeeId: committeeId,
                  roleInCommittee: inCommittee.role,
                  isHrOrAdmin: isHrOrAdmin,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.member, required this.roleInCommittee});
  final UserWithRoles member;
  final String roleInCommittee;
  @override
  Widget build(BuildContext context) {
    final roleLabel = switch (roleInCommittee) {
      'head' => 'قائد اللجنة',
      'vice_head' => 'نائب قائد اللجنة',
      _ => 'عضو',
    };
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.purpleGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            member.fullName.isEmpty
                ? '?'
                : member.fullName.characters.first.toUpperCase(),
            style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 34),
          ),
        ),
        const SizedBox(height: 12),
        Text(member.fullName,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(roleLabel,
            style: GoogleFonts.cairo(
                color: Colors.white70, fontSize: 13)),
      ]),
    );
  }
}

class _HoursStats extends ConsumerWidget {
  const _HoursStats({required this.userId});
  final String userId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(memberHoursSummaryProvider(userId));
    final unit = ref.watch(hoursUnitProvider);
    return summary.when(
      loading: () => const AppCard(
        child: SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => AppCard(child: Text('${S.error}: $e')),
      data: (s) {
        Widget cell(String label, int v, Color color) => Expanded(
              child: StatTile(
                  label: label,
                  value: formatVolunteerTime(v, unit),
                  color: color,
                  icon: Icons.access_time),
            );
        return Column(children: [
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
        ]);
      },
    );
  }
}

class _TaskStats extends StatelessWidget {
  const _TaskStats({required this.tasks});
  final List<Task> tasks;
  @override
  Widget build(BuildContext context) {
    final completed =
        tasks.where((t) => t.status == TaskStatus.completed).length;
    final inProgress =
        tasks.where((t) => t.status == TaskStatus.inProgress).length;
    final overdue =
        tasks.where((t) => t.status == TaskStatus.overdue).length;
    Widget cell(String label, int v, Color c) => Expanded(
        child: StatTile(label: label, value: '$v', color: c));
    return Column(children: [
      Row(children: [
        cell(S.totalTasks, tasks.length, AppColors.textPrimary),
        const SizedBox(width: 8),
        cell(S.completed, completed, AppColors.statusCompleted),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        cell(S.overdue, overdue, AppColors.statusOverdue),
        const SizedBox(width: 8),
        cell(S.inProgress, inProgress, AppColors.statusInProgress),
      ]),
    ]);
  }
}

class _ActionsCard extends ConsumerStatefulWidget {
  const _ActionsCard({
    required this.member,
    required this.committeeId,
    required this.roleInCommittee,
    required this.isHrOrAdmin,
  });
  final UserWithRoles member;
  final int committeeId;
  final String roleInCommittee;
  final bool isHrOrAdmin;

  @override
  ConsumerState<_ActionsCard> createState() => _ActionsCardState();
}

class _ActionsCardState extends ConsumerState<_ActionsCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() op, {String? success}) async {
    setState(() => _busy = true);
    try {
      await op();
      ref.invalidate(allMembersProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ?? 'تم بنجاح')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${S.error}: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body) async {
    return (await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title, style: GoogleFonts.cairo()),
            content: Text(body, style: GoogleFonts.cairo()),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(S.cancel)),
              TextButton(
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.statusOverdue),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(S.confirm),
              ),
            ],
          ),
        )) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(committeeRepositoryProvider);
    final role = widget.roleInCommittee;

    final buttons = <Widget>[];

    // Promote member → vice_head
    if (role == 'member') {
      buttons.add(_actionButton(
        label: 'ترقية إلى نائب القائد',
        icon: Icons.arrow_upward,
        color: AppColors.purple,
        onPressed: () async {
          if (!await _confirm(
              'تأكيد الترقية', 'ترقية ${widget.member.fullName} إلى نائب قائد اللجنة؟')) {
            return;
          }
          await _run(
              () => repo.changeRole(
                  userId: widget.member.id,
                  committeeId: widget.committeeId,
                  newRole: 'vice_head'),
              success: 'تمت الترقية');
        },
      ));
    }
    // Demote vice_head → member
    if (role == 'vice_head') {
      buttons.add(_actionButton(
        label: 'تخفيض إلى عضو',
        icon: Icons.arrow_downward,
        color: AppColors.statusInProgress,
        onPressed: () async {
          if (!await _confirm('تأكيد التخفيض',
              'تخفيض ${widget.member.fullName} إلى عضو؟')) {
            return;
          }
          await _run(
              () => repo.changeRole(
                  userId: widget.member.id,
                  committeeId: widget.committeeId,
                  newRole: 'member'),
              success: 'تم التخفيض');
        },
      ));
    }

    // HR/admin only: promote → head OR demote head → vice
    if (widget.isHrOrAdmin) {
      if (role != 'head') {
        buttons.add(_actionButton(
          label: 'تعيين قائدًا للجنة',
          icon: Icons.star_outline,
          color: AppColors.statusCompleted,
          onPressed: () async {
            if (!await _confirm('تأكيد التعيين',
                'جعل ${widget.member.fullName} قائد اللجنة؟ سيتم استبدال أي قائد سابق.')) {
              return;
            }
            await _run(
                () => repo.changeRole(
                    userId: widget.member.id,
                    committeeId: widget.committeeId,
                    newRole: 'head'),
                success: 'تم التعيين');
          },
        ));
      }
      if (role == 'head') {
        buttons.add(_actionButton(
          label: 'تخفيض من قائد إلى نائب',
          icon: Icons.arrow_downward,
          color: AppColors.statusInProgress,
          onPressed: () async {
            if (!await _confirm('تأكيد التخفيض',
                'تخفيض ${widget.member.fullName} من قائد إلى نائب؟')) {
              return;
            }
            await _run(
                () => repo.changeRole(
                    userId: widget.member.id,
                    committeeId: widget.committeeId,
                    newRole: 'vice_head'),
                success: 'تم التخفيض');
          },
        ));
      }
    }

    // Edit member info — anyone managing this committee can edit
    buttons.add(_actionButton(
      label: 'تعديل معلومات العضو',
      icon: Icons.edit_outlined,
      color: AppColors.purple,
      onPressed: () => context.push(
        '/members/${widget.member.id}/edit'
        '?committee=${widget.committeeId}',
      ),
    ));

    // Remove from this committee
    buttons.add(_actionButton(
      label: 'إزالة من اللجنة',
      icon: Icons.person_remove_outlined,
      color: AppColors.statusOverdue,
      onPressed: () async {
        if (!await _confirm('تأكيد الإزالة',
            'إزالة ${widget.member.fullName} من هذه اللجنة؟ سيبقى في باقي لجانه (إن وُجدت).')) {
          return;
        }
        await _run(
            () => repo.removeFromCommittee(
                userId: widget.member.id,
                committeeId: widget.committeeId),
            success: 'تمت الإزالة');
        if (!mounted) return;
        if (context.mounted) context.pop();
      },
    ));

    // Delete from system (HR/admin only)
    if (widget.isHrOrAdmin) {
      buttons.add(_actionButton(
        label: 'حذف العضو من النظام نهائيًا',
        icon: Icons.delete_forever_outlined,
        color: AppColors.statusOverdue,
        onPressed: () async {
          if (!await _confirm(
              'تأكيد الحذف النهائي',
              'حذف ${widget.member.fullName} من النظام بالكامل؟ هذا الإجراء لا يمكن التراجع عنه.')) {
            return;
          }
          await _run(() => repo.deleteMember(widget.member.id),
              success: 'تم الحذف');
          if (!mounted) return;
          if (context.mounted) context.pop();
        },
      ));
    }

    return AppCard(
      child: Column(children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          buttons[i],
        ],
        if (_busy) const Padding(
          padding: EdgeInsets.only(top: 10),
          child: LinearProgressIndicator(),
        ),
      ]),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          textStyle:
              GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label),
        onPressed: _busy ? null : onPressed,
      ),
    );
  }
}
