import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/localization/strings.dart';
import '../../core/permissions/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/committee.dart';
import '../../data/models/team.dart';
import '../../data/models/user_with_roles.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/committee_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/team_repository.dart';
import '../../shared/widgets/design_system.dart';
import '../../shared/widgets/empty_state.dart';

/// Hierarchical directory:
///   * Top: قيادة النادي (admins + board + leadership)
///   * Then each committee as a collapsible section, sorted internally
///     by role (head → vice → members alphabetical).
///   * Under Media, the 4 permanent sub-teams are also collapsible.
///
/// When the user searches, the hierarchy collapses to a flat
/// matching list with each member's primary committee shown inline.
class MembersDirectoryScreen extends ConsumerStatefulWidget {
  const MembersDirectoryScreen({super.key});

  @override
  ConsumerState<MembersDirectoryScreen> createState() =>
      _MembersDirectoryScreenState();
}

class _MembersDirectoryScreenState
    extends ConsumerState<MembersDirectoryScreen> {
  String _query = '';
  final Set<String> _collapsed = {};

  bool _isOpen(String key, {bool defaultOpen = true}) {
    if (defaultOpen) return !_collapsed.contains(key);
    return _collapsed.contains('open:$key');
  }

  void _toggle(String key, {bool defaultOpen = true}) {
    setState(() {
      if (defaultOpen) {
        if (_collapsed.contains(key)) {
          _collapsed.remove(key);
        } else {
          _collapsed.add(key);
        }
      } else {
        if (_collapsed.contains('open:$key')) {
          _collapsed.remove('open:$key');
        } else {
          _collapsed.add('open:$key');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(allMembersProvider);
    final committeesAsync = ref.watch(committeesProvider);
    final teamsAsync = ref.watch(teamsProvider);
    final meAsync = ref.watch(currentUserProvider);
    final perms = Permissions(meAsync.value);

    // Show "+ إضافة عضو" if the user can manage at least one committee.
    final headedCommittee = meAsync.value?.committees
        .where((c) => c.role == 'head' || c.role == 'vice_head')
        .firstOrNull;
    final canAddMember = perms.isHrOrAdmin || headedCommittee != null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: canAddMember
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.purple,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add),
              label: Text('إضافة عضو',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
              onPressed: () {
                // For HR/admin, default to the first committee just so the
                // screen has a starting value; the form has a dropdown.
                // For a committee head, default to their own committee.
                final cId = headedCommittee?.committeeId ??
                    (perms.isHrOrAdmin
                        ? (ref.read(committeesProvider).value?.first.id ?? 1)
                        : 1);
                final name = headedCommittee?.committeeNameAr ?? '';
                context.push(
                    '/committees/$cId/members/new?name=${Uri.encodeComponent(name)}');
              },
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Column(
            children: [
              GradientHero(
                title: S.memberDirectory,
                subtitle: S.members,
                bottom: _SearchField(
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: membersAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('${S.error}: $e')),
                  data: (members) {
                    if (_query.isNotEmpty) {
                      return _FlatSearchList(
                          members: members, query: _query);
                    }
                    final committees =
                        committeesAsync.value ?? const <Committee>[];
                    final teams = teamsAsync.value ?? const <Team>[];
                    return _HierarchicalList(
                      members: members,
                      committees: committees,
                      teams: teams,
                      isOpen: _isOpen,
                      onToggle: _toggle,
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

// ─── header sections ─────────────────────────────────────────────────

class _HierarchicalList extends StatelessWidget {
  const _HierarchicalList({
    required this.members,
    required this.committees,
    required this.teams,
    required this.isOpen,
    required this.onToggle,
  });
  final List<UserWithRoles> members;
  final List<Committee> committees;
  final List<Team> teams;
  final bool Function(String, {bool defaultOpen}) isOpen;
  final void Function(String, {bool defaultOpen}) onToggle;

  static const _adminOrder = [
    'club_leader',
    'club_vice_leader',
    'board_member',
  ];
  static const _committeeIcons = {
    'Human Resources': Icons.groups_2_outlined,
    'Project Management': Icons.assignment_outlined,
    'Public Relations': Icons.campaign_outlined,
    'Quality & Development': Icons.verified_outlined,
    'Activity Management': Icons.event_outlined,
    'Technology': Icons.computer_outlined,
    'Guidance': Icons.support_outlined,
    'Media': Icons.movie_outlined,
  };

  @override
  Widget build(BuildContext context) {
    // ─── partition members ──────────────────────────────────────────
    // Leadership = anyone with a club_role
    final leaders = members.where((m) => m.clubRole != null).toList();
    // Group by club_role
    final byRole = <String, List<UserWithRoles>>{};
    for (final m in leaders) {
      byRole.putIfAbsent(m.clubRole!, () => []).add(m);
    }
    // Sort each group alphabetically
    for (final list in byRole.values) {
      list.sort((a, b) => a.fullName.compareTo(b.fullName));
    }

    // Map committeeId → its members, sorted (head → vice → alpha)
    final perCommittee = <int, List<UserWithRoles>>{};
    for (final m in members) {
      for (final c in m.committees) {
        perCommittee.putIfAbsent(c.committeeId, () => []).add(m);
      }
    }
    int rank(String role) =>
        role == 'head' ? 0 : (role == 'vice_head' ? 1 : 2);
    for (final entry in perCommittee.entries) {
      entry.value.sort((a, b) {
        final ra = a.committees
            .firstWhere((c) => c.committeeId == entry.key)
            .role;
        final rb = b.committees
            .firstWhere((c) => c.committeeId == entry.key)
            .role;
        final cmp = rank(ra).compareTo(rank(rb));
        if (cmp != 0) return cmp;
        return a.fullName.compareTo(b.fullName);
      });
    }

    // ─── Media sub-teams ────────────────────────────────────────────
    final mediaCommittee =
        committees.where((c) => c.nameEn == 'Media').firstOrNull;
    final mediaTeams = mediaCommittee == null
        ? <Team>[]
        : teams.where((t) => t.isPermanent).toList();

    // ─── build list ─────────────────────────────────────────────────
    final children = <Widget>[];

    // 1. Leadership group: club_leader + club_vice_leader → "قيادة الفريق"
    final leadership = <UserWithRoles>[];
    for (final r in _adminOrder.take(2)) {
      leadership.addAll(byRole[r] ?? const []);
    }
    if (leadership.isNotEmpty) {
      children.add(_LeaderSection(
        title: 'قيادة الفريق',
        members: leadership,
        keyId: 'leadership',
        isOpen: isOpen('leadership'),
        onToggle: () => onToggle('leadership'),
      ));
    }

    // 2. Board section: board_member + president + vice → "مجلس الإدارة"
    // app_admin is intentionally excluded — they appear only in their
    // committee with a dedicated "عضو - مدير نظام التطبيق" badge.
    final board = <UserWithRoles>[];
    for (final r in ['president', 'vice_president', 'board_member']) {
      board.addAll(byRole[r] ?? const []);
    }
    if (board.isNotEmpty) {
      children.add(_LeaderSection(
        title: 'مجلس الإدارة',
        members: board,
        keyId: 'board',
        isOpen: isOpen('board'),
        onToggle: () => onToggle('board'),
      ));
    }

    // 3. Each committee
    final orderedCommittees = [...committees]
      ..sort((a, b) => a.id.compareTo(b.id));
    for (final c in orderedCommittees) {
      final list = perCommittee[c.id] ?? const <UserWithRoles>[];
      // For Media: only show the committee head + vice; sub-teams below.
      if (c.nameEn == 'Media') {
        children.add(_CommitteeSection(
          committee: c,
          members: list,
          icon: _committeeIcons[c.nameEn] ?? Icons.groups,
          isOpen: isOpen('committee:${c.id}'),
          onToggle: () => onToggle('committee:${c.id}'),
          extraChildren: [
            for (final t in mediaTeams)
              _TeamSection(
                team: t,
                allMembers: members,
                keyId: 'team:${t.id}',
                isOpen:
                    isOpen('team:${t.id}', defaultOpen: false),
                onToggle: () =>
                    onToggle('team:${t.id}', defaultOpen: false),
              ),
          ],
        ));
      } else {
        children.add(_CommitteeSection(
          committee: c,
          members: list,
          icon: _committeeIcons[c.nameEn] ?? Icons.groups,
          isOpen: isOpen('committee:${c.id}'),
          onToggle: () => onToggle('committee:${c.id}'),
        ));
      }
    }

    if (children.isEmpty) return const EmptyState(message: S.noData);
    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: children,
    );
  }
}

// ─── search results ──────────────────────────────────────────────────

class _FlatSearchList extends StatelessWidget {
  const _FlatSearchList({required this.members, required this.query});
  final List<UserWithRoles> members;
  final String query;

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    final filtered = members
        .where((m) =>
            m.fullName.contains(query) ||
            m.committees.any((c) =>
                c.committeeNameAr.contains(query) ||
                c.committeeNameEn.toLowerCase().contains(q)))
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    if (filtered.isEmpty) {
      return const EmptyState(message: S.noData);
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _MemberCard(member: filtered[i]),
    );
  }
}

// ─── leader / committee / team sections ──────────────────────────────

class _LeaderSection extends StatelessWidget {
  const _LeaderSection({
    required this.title,
    required this.members,
    required this.keyId,
    required this.isOpen,
    required this.onToggle,
  });
  final String title;
  final List<UserWithRoles> members;
  final String keyId;
  final bool isOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _PurpleHeader(
          title: title,
          countLabel: '${members.length} أعضاء',
          isOpen: isOpen,
          onTap: onToggle,
        ),
        if (isOpen)
          for (final m in members)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _MemberCard(member: m, showClubRole: true),
            ),
      ]),
    );
  }
}

class _CommitteeSection extends StatelessWidget {
  const _CommitteeSection({
    required this.committee,
    required this.members,
    required this.icon,
    required this.isOpen,
    required this.onToggle,
    this.extraChildren = const [],
  });
  final Committee committee;
  final List<UserWithRoles> members;
  final IconData icon;
  final bool isOpen;
  final VoidCallback onToggle;
  final List<Widget> extraChildren;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _PurpleHeader(
          title: 'لجنة ${committee.nameAr}',
          countLabel: '${members.length} عضو',
          icon: icon,
          isOpen: isOpen,
          onTap: onToggle,
        ),
        if (isOpen) ...[
          for (final m in members)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _MemberCard(
                  member: m, committeeId: committee.id),
            ),
          for (final extra in extraChildren) ...[
            const SizedBox(height: 8),
            extra,
          ],
        ],
      ]),
    );
  }
}

class _TeamSection extends StatelessWidget {
  const _TeamSection({
    required this.team,
    required this.allMembers,
    required this.keyId,
    required this.isOpen,
    required this.onToggle,
  });
  final Team team;
  final List<UserWithRoles> allMembers;
  final String keyId;
  final bool isOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    // Sort: leader → vice_leader → member (alphabetical within each)
    int rank(String r) =>
        r == 'leader' ? 0 : (r == 'vice_leader' ? 1 : 2);
    final byId = {for (final m in allMembers) m.id: m};
    final rows = team.members
        .where((r) => byId.containsKey(r.userId))
        .toList()
      ..sort((a, b) {
        final c = rank(a.role).compareTo(rank(b.role));
        if (c != 0) return c;
        return byId[a.userId]!.fullName.compareTo(byId[b.userId]!.fullName);
      });
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _LightPurpleHeader(
          title: team.name,
          countLabel: '${team.members.length} أعضاء',
          isOpen: isOpen,
          onTap: onToggle,
        ),
        if (isOpen)
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _MemberCard(
                member: byId[r.userId]!,
                teamRoleLabel: switch (r.role) {
                  'leader' => 'قائد الفريق',
                  'vice_leader' => 'نائب قائد الفريق',
                  _ => 'عضو الفريق',
                },
              ),
            ),
      ]),
    );
  }
}

// ─── header widgets ──────────────────────────────────────────────────

class _PurpleHeader extends StatelessWidget {
  const _PurpleHeader({
    required this.title,
    required this.countLabel,
    this.icon,
    required this.isOpen,
    required this.onTap,
  });
  final String title;
  final String countLabel;
  final IconData? icon;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: AppColors.purpleGradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Icon(isOpen ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_left,
              color: Colors.white, size: 20),
          const SizedBox(width: 4),
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(title,
                style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(countLabel,
                style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

class _LightPurpleHeader extends StatelessWidget {
  const _LightPurpleHeader({
    required this.title,
    required this.countLabel,
    required this.isOpen,
    required this.onTap,
  });
  final String title;
  final String countLabel;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.purpleLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(isOpen ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_left,
              color: AppColors.purple, size: 18),
          const SizedBox(width: 4),
          Icon(Icons.workspaces_outlined,
              color: AppColors.purple, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(title,
                style: GoogleFonts.cairo(
                    color: AppColors.purple,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ),
          Text(countLabel,
              style: GoogleFonts.cairo(
                  color: AppColors.purple,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

// ─── member card ─────────────────────────────────────────────────────

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    this.committeeId,
    this.teamRoleLabel,
    this.showClubRole = false,
  });
  final UserWithRoles member;
  final int? committeeId;
  final String? teamRoleLabel;
  final bool showClubRole;

  @override
  Widget build(BuildContext context) {
    String? roleLabel;
    Color roleColor = AppColors.statusPending;
    if (teamRoleLabel != null) {
      roleLabel = teamRoleLabel;
      roleColor = AppColors.purpleAccent;
    } else if (committeeId != null) {
      final cm = member.committees
          .firstWhere((c) => c.committeeId == committeeId!,
              orElse: () => member.committees.first);
      roleLabel = switch (cm.role) {
        'head' => 'رئيس اللجنة',
        'vice_head' => 'نائب الرئيس',
        _ => 'عضو',
      };
      roleColor = switch (cm.role) {
        'head' => AppColors.purple,
        'vice_head' => AppColors.purpleAccent,
        _ => AppColors.statusPending,
      };
      // Special case: app_admin shown inside their committee gets a
      // dedicated dual-role badge per spec.
      if (member.clubRole == 'app_admin' && cm.role == 'member') {
        roleLabel = 'عضو - مدير نظام التطبيق';
        roleColor = AppColors.purpleDark;
      }
    } else if (showClubRole && member.clubRole != null) {
      roleLabel = _clubRoleAr(member.clubRole!);
      roleColor = AppColors.purple;
    }

    // Secondary line: their other affiliations
    final affiliations = <String>[];
    for (final c in member.committees) {
      if (committeeId != null && c.committeeId == committeeId) continue;
      affiliations.add(c.committeeNameAr);
    }
    final subtitle = affiliations.isEmpty
        ? (committeeId != null
            ? member.committees
                .firstWhere((c) => c.committeeId == committeeId)
                .committeeNameAr
            : '')
        : (committeeId != null
            ? 'أيضًا في: ${affiliations.join(' • ')}'
            : affiliations.join(' • '));

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      onTap: () => context.push('/members/${member.id}'),
      child: Row(children: [
        InitialAvatar(name: member.fullName, radius: 20),
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
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: AppColors.textSecondary)),
              ],
            ],
          ),
        ),
        if (roleLabel != null) ...[
          const SizedBox(width: 8),
          Pill(label: roleLabel, color: roleColor),
        ],
      ]),
    );
  }

  static String _clubRoleAr(String r) => switch (r) {
        'president' => 'رئيس النادي',
        'vice_president' => 'نائب الرئيس',
        'board_member' => 'مجلس الإدارة',
        'club_leader' => 'قائد الفريق',
        'club_vice_leader' => 'نائب القائد',
        'app_admin' => 'مدير النظام',
        _ => 'عضو',
      };
}

// ─── search field ────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});
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
          hintText: S.searchMembers,
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
