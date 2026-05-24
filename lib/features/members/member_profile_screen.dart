import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/localization/formatters.dart';
import '../../core/localization/strings.dart';
import '../../core/permissions/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_with_roles.dart';
import '../../data/models/volunteer_hours.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/committee_repository.dart';
import '../../data/repositories/hours_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../shared/widgets/design_system.dart';
import '../../shared/widgets/empty_state.dart';
import '../hours/hours_unit.dart';

class MemberProfileScreen extends ConsumerWidget {
  const MemberProfileScreen({super.key, required this.memberId});
  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(allMembersProvider);
    final meAsync = ref.watch(currentUserProvider);
    final perms = Permissions(meAsync.value);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text(S.memberDirectory)),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${S.error}: $e')),
        data: (members) {
          final m = members.where((x) => x.id == memberId).firstOrNull;
          if (m == null) return const EmptyState(message: S.noData);
          final manageableCommittees = m.committees
              .where((c) => perms.canManageCommittee(c.committeeId))
              .toList();
          final showActions = manageableCommittees.isNotEmpty ||
              perms.isHrOrAdmin;
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
              if (showActions) ...[
                const SectionTitle('إجراءات إدارية'),
                _AdminActionsCard(
                  member: m,
                  manageableCommittees: manageableCommittees,
                  isHrOrAdmin: perms.isHrOrAdmin,
                ),
              ],
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
    final unit = ref.watch(hoursUnitProvider);
    return summaryAsync.when(
      loading: () => const AppCard(
        child: SizedBox(
            height: 80, child: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => AppCard(child: Text('${S.error}: $e')),
      data: (s) {
        Widget cell(String label, int v, Color color) => Expanded(
              child: StatTile(
                label: label,
                value: formatVolunteerTime(v, unit),
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

class _SessionMiniRow extends ConsumerWidget {
  const _SessionMiniRow({required this.session});
  final VolunteerHours session;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(hoursUnitProvider);
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
        Text(formatVolunteerTime(session.minutes, unit),
            style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.purple)),
      ]),
    );
  }
}

/// Admin actions card — visible to: HR (any member), admin (any), or
/// committee head (only for members of their own committee).
class _AdminActionsCard extends ConsumerStatefulWidget {
  const _AdminActionsCard({
    required this.member,
    required this.manageableCommittees,
    required this.isHrOrAdmin,
  });
  final UserWithRoles member;
  final List<dynamic> manageableCommittees; // CommitteeMembership entries
  final bool isHrOrAdmin;

  @override
  ConsumerState<_AdminActionsCard> createState() =>
      _AdminActionsCardState();
}

class _AdminActionsCardState extends ConsumerState<_AdminActionsCard> {
  bool _busy = false;

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

  Future<void> _run(Future<void> Function() op,
      {String? success, VoidCallback? after}) async {
    setState(() => _busy = true);
    try {
      await op();
      ref.invalidate(allMembersProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ?? 'تم بنجاح')));
      after?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${S.error}: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(committeeRepositoryProvider);
    final children = <Widget>[];

    // ─── Global actions ───────────────────────────────────────────
    children.add(_btn(
      label: 'تعديل معلومات العضو',
      icon: Icons.edit_outlined,
      color: AppColors.purple,
      onPressed: () => context.push('/members/${widget.member.id}/edit'),
    ));

    if (widget.isHrOrAdmin) {
      children.add(const SizedBox(height: 8));
      children.add(_btn(
        label: 'إضافة لِلجنة أخرى',
        icon: Icons.group_add_outlined,
        color: AppColors.statusCompleted,
        onPressed: () => _showAddToCommitteeSheet(repo),
      ));
    }

    // ─── App-admin god-mode: club role assignment ─────────────────
    final perms = Permissions(ref.read(currentUserProvider).value);
    if (perms.isAppAdmin) {
      children.add(const SizedBox(height: 14));
      children.add(_godModeHeader());
      children.add(const SizedBox(height: 6));
      children.add(_btn(
        label: widget.member.clubRole == null
            ? 'تعيين دور قيادي للنادي'
            : 'تغيير الدور القيادي (الحالي: ${_clubRoleAr(widget.member.clubRole!)})',
        icon: Icons.shield_outlined,
        color: AppColors.purpleDark,
        onPressed: () => _showSetClubRoleSheet(repo),
      ));
      if (widget.member.clubRole != null) {
        children.add(const SizedBox(height: 6));
        children.add(_btn(
          label: 'إزالة الدور القيادي',
          icon: Icons.remove_circle_outline,
          color: AppColors.statusOverdue,
          onPressed: () async {
            if (!await _confirm('تأكيد الإزالة',
                'إزالة ${widget.member.fullName} من ${_clubRoleAr(widget.member.clubRole!)}؟')) {
              return;
            }
            await _run(
                () => repo.setClubRole(
                    userId: widget.member.id, role: null),
                success: 'تمت الإزالة');
          },
        ));
      }
    }

    // ─── Per-committee actions ────────────────────────────────────
    for (final c in widget.manageableCommittees) {
      final cid = c.committeeId as int;
      final role = c.role as String;
      final committeeNameAr = c.committeeNameAr as String;

      children.add(const SizedBox(height: 14));
      children.add(_committeeHeader(committeeNameAr));

      // Promote / demote
      if (role == 'member') {
        children.add(const SizedBox(height: 6));
        children.add(_btn(
          label: 'ترقية إلى نائب الرئيس — $committeeNameAr',
          icon: Icons.arrow_upward,
          color: AppColors.purple,
          onPressed: () async {
            if (!await _confirm('تأكيد الترقية',
                'ترقية ${widget.member.fullName} إلى نائب رئيس $committeeNameAr؟')) {
              return;
            }
            await _run(
                () => repo.changeRole(
                    userId: widget.member.id,
                    committeeId: cid,
                    newRole: 'vice_head'),
                success: 'تمت الترقية');
          },
        ));
      }
      if (role == 'vice_head') {
        children.add(const SizedBox(height: 6));
        children.add(_btn(
          label: 'تخفيض إلى عضو — $committeeNameAr',
          icon: Icons.arrow_downward,
          color: AppColors.statusInProgress,
          onPressed: () async {
            if (!await _confirm('تأكيد التخفيض',
                'تخفيض ${widget.member.fullName} إلى عضو في $committeeNameAr؟')) {
              return;
            }
            await _run(
                () => repo.changeRole(
                    userId: widget.member.id,
                    committeeId: cid,
                    newRole: 'member'),
                success: 'تم التخفيض');
          },
        ));
      }

      // Head promotion/demotion — HR/admin only
      if (widget.isHrOrAdmin) {
        if (role != 'head') {
          children.add(const SizedBox(height: 6));
          children.add(_btn(
            label: 'تعيين قائدًا — $committeeNameAr',
            icon: Icons.star_outline,
            color: AppColors.statusCompleted,
            onPressed: () async {
              if (!await _confirm('تأكيد التعيين',
                  'تعيين ${widget.member.fullName} قائدًا للجنة $committeeNameAr؟')) {
                return;
              }
              await _run(
                  () => repo.changeRole(
                      userId: widget.member.id,
                      committeeId: cid,
                      newRole: 'head'),
                  success: 'تم التعيين');
            },
          ));
        } else {
          children.add(const SizedBox(height: 6));
          children.add(_btn(
            label: 'تخفيض من قائد إلى نائب — $committeeNameAr',
            icon: Icons.arrow_downward,
            color: AppColors.statusInProgress,
            onPressed: () async {
              if (!await _confirm('تأكيد التخفيض',
                  'تخفيض ${widget.member.fullName} من قائد إلى نائب رئيس $committeeNameAr؟')) {
                return;
              }
              await _run(
                  () => repo.changeRole(
                      userId: widget.member.id,
                      committeeId: cid,
                      newRole: 'vice_head'),
                  success: 'تم التخفيض');
            },
          ));
        }
      }

      // Remove from this committee
      children.add(const SizedBox(height: 6));
      children.add(_btn(
        label: 'إزالة من $committeeNameAr',
        icon: Icons.person_remove_outlined,
        color: AppColors.statusOverdue,
        onPressed: () async {
          if (!await _confirm('تأكيد الإزالة',
              'إزالة ${widget.member.fullName} من لجنة $committeeNameAr؟ سيبقى في باقي لجانه إن وُجدت.')) {
            return;
          }
          await _run(
              () => repo.removeFromCommittee(
                  userId: widget.member.id, committeeId: cid),
              success: 'تمت الإزالة');
        },
      ));
    }

    // ─── HR/admin only: delete user entirely ──────────────────────
    if (widget.isHrOrAdmin) {
      children.add(const SizedBox(height: 14));
      children.add(_btn(
        label: 'حذف العضو من النظام نهائيًا',
        icon: Icons.delete_forever_outlined,
        color: AppColors.statusOverdue,
        onPressed: () async {
          if (!await _confirm(
              'تأكيد الحذف النهائي',
              'حذف ${widget.member.fullName} من النظام بالكامل؟ هذا الإجراء لا يمكن التراجع عنه.')) {
            return;
          }
          await _run(
            () => repo.deleteMember(widget.member.id),
            success: 'تم حذف العضو',
            after: () {
              if (context.mounted) context.pop();
            },
          );
        },
      ));
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...children,
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _godModeHeader() => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: Row(children: [
          const Icon(Icons.workspace_premium_outlined,
              color: AppColors.purpleDark, size: 16),
          const SizedBox(width: 6),
          Text('صلاحيات مدير النظام',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800,
                  color: AppColors.purpleDark,
                  fontSize: 13)),
        ]),
      );

  Future<void> _showSetClubRoleSheet(CommitteeRepository repo) async {
    const options = [
      ('president', 'رئيس النادي'),
      ('vice_president', 'نائب رئيس النادي'),
      ('board_member', 'عضو مجلس الإدارة'),
      ('club_leader', 'قائد الفريق'),
      ('club_vice_leader', 'نائب قائد الفريق'),
      ('app_admin', 'مدير النظام'),
    ];
    final pickedRole = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('اختر الدور',
                  style: GoogleFonts.cairo(
                      fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            for (final o in options)
              ListTile(
                leading: const Icon(Icons.shield_outlined,
                    color: AppColors.purple),
                title: Text(o.$2, style: GoogleFonts.cairo()),
                onTap: () => Navigator.pop(context, o.$1),
              ),
          ],
        ),
      ),
    );
    if (pickedRole == null) return;
    if (!await _confirm('تأكيد التعيين',
        'تعيين ${widget.member.fullName} بدور: ${_clubRoleAr(pickedRole)}؟')) {
      return;
    }
    await _run(
        () => repo.setClubRole(
            userId: widget.member.id, role: pickedRole),
        success: 'تم التعيين');
  }

  static String _clubRoleAr(String r) => switch (r) {
        'president' => 'رئيس النادي',
        'vice_president' => 'نائب رئيس النادي',
        'board_member' => 'عضو مجلس الإدارة',
        'club_leader' => 'قائد الفريق',
        'club_vice_leader' => 'نائب قائد الفريق',
        'app_admin' => 'مدير النظام',
        _ => r,
      };

  Widget _committeeHeader(String name) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: Row(children: [
          const Icon(Icons.groups_2_outlined,
              color: AppColors.purple, size: 16),
          const SizedBox(width: 6),
          Text(name,
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800,
                  color: AppColors.purple,
                  fontSize: 13)),
        ]),
      );

  Widget _btn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) =>
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: 0.5)),
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            textStyle: GoogleFonts.cairo(
                fontSize: 13, fontWeight: FontWeight.w700),
          ),
          icon: Icon(icon, size: 18),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          onPressed: _busy ? null : onPressed,
        ),
      );

  Future<void> _showAddToCommitteeSheet(CommitteeRepository repo) async {
    final committees = ref.read(committeesProvider).value ?? [];
    final currentIds = widget.member.committees
        .map((c) => c.committeeId)
        .toSet();
    final available =
        committees.where((c) => !currentIds.contains(c.id)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('العضو موجود في جميع اللجان بالفعل')),
      );
      return;
    }
    final pickedId = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('اختر اللجنة',
                  style: GoogleFonts.cairo(
                      fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            for (final c in available)
              ListTile(
                leading: const Icon(Icons.groups_2_outlined,
                    color: AppColors.purple),
                title: Text(c.nameAr, style: GoogleFonts.cairo()),
                onTap: () => Navigator.pop(context, c.id),
              ),
          ],
        ),
      ),
    );
    if (pickedId == null) return;
    await _run(
        () => repo.addMember(
            userId: widget.member.id, committeeId: pickedId),
        success: 'تمت الإضافة');
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
