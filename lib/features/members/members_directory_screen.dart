import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/localization/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_with_roles.dart';
import '../../data/repositories/profile_repository.dart';
import '../../shared/widgets/design_system.dart';
import '../../shared/widgets/empty_state.dart';

class MembersDirectoryScreen extends ConsumerStatefulWidget {
  const MembersDirectoryScreen({super.key});

  @override
  ConsumerState<MembersDirectoryScreen> createState() =>
      _MembersDirectoryScreenState();
}

class _MembersDirectoryScreenState
    extends ConsumerState<MembersDirectoryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(allMembersProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
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
                    final q = _query;
                    final filtered = q.isEmpty
                        ? members
                        : members
                            .where((m) =>
                                m.fullName.contains(q) ||
                                m.committees.any((c) =>
                                    c.committeeNameAr.contains(q) ||
                                    c.committeeNameEn
                                        .toLowerCase()
                                        .contains(q.toLowerCase())))
                            .toList();
                    if (filtered.isEmpty) {
                      return const EmptyState(message: S.noData);
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _MemberCard(member: filtered[i]),
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
          prefixIcon:
              const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
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

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member});
  final UserWithRoles member;

  @override
  Widget build(BuildContext context) {
    final committeeLabel = member.committees.isNotEmpty
        ? member.committees.first.committeeNameAr
        : '';
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => context.push('/members/${member.id}'),
      child: Row(
        children: [
          InitialAvatar(name: member.fullName, radius: 22, fontSize: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.fullName,
                    style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                if (committeeLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(committeeLabel,
                      style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Pill(label: _shortRole(member), color: _roleColor(member)),
        ],
      ),
    );
  }

  String _shortRole(UserWithRoles m) {
    switch (m.clubRole) {
      case 'president':
        return S.president;
      case 'vice_president':
        return S.vicePresident;
      case 'board_member':
        return 'مجلس الإدارة';
      case 'club_leader':
        return 'قائد';
      case 'club_vice_leader':
        return 'نائب قائد';
      case 'app_admin':
        return 'مدير';
    }
    if (m.committees.any((c) => c.role == 'head')) return S.head;
    if (m.committees.any((c) => c.role == 'vice_head')) return S.viceHead;
    return S.member;
  }

  Color _roleColor(UserWithRoles m) {
    if (m.clubRole != null) return AppColors.purple;
    if (m.committees.any((c) => c.role == 'head')) {
      return AppColors.statusInProgress;
    }
    if (m.committees.any((c) => c.role == 'vice_head')) {
      return AppColors.purpleAccent;
    }
    return AppColors.statusPending;
  }
}
