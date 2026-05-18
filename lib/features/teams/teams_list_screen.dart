import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/localization/strings.dart';
import '../../core/permissions/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/team.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/team_repository.dart';
import '../../shared/widgets/design_system.dart';
import '../../shared/widgets/empty_state.dart';

class TeamsListScreen extends ConsumerWidget {
  const TeamsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(teamsProvider);
    final meAsync = ref.watch(currentUserProvider);
    final canCreate = meAsync.maybeWhen(
      data: (me) => Permissions(me).isPresident,
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.purple,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text('إنشاء فريق',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
              onPressed: () => context.push('/teams/new'),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Column(
            children: [
              GradientHero(
                title: 'الفِرَق',
                subtitle: 'فِرَق العمل واللجان الفرعية',
                actions: canCreate
                    ? [
                        PillButton.primary(
                          label: '+ إضافة فريق',
                          onPressed: () => context.push('/teams/new'),
                        ),
                      ]
                    : null,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: teamsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('${S.error}: $e')),
                  data: (teams) {
                    if (teams.isEmpty) {
                      return const EmptyState(message: S.noData);
                    }
                    return RefreshIndicator(
                      onRefresh: () async => ref.invalidate(teamsProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: teams.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _TeamCard(team: teams[i]),
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

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team});
  final Team team;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      onTap: () => context.push('/teams/${team.id}'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.purpleLight,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.groups_2_outlined,
                color: AppColors.purple, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        team.name,
                        style: GoogleFonts.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary),
                      ),
                    ),
                    if (team.isPermanent) ...[
                      const SizedBox(width: 6),
                      const Pill(label: 'دائم', color: AppColors.statusCompleted),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  (team.description == null || team.description!.isEmpty)
                      ? '${team.memberIds.length} عضو'
                      : team.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${team.memberIds.length} عضو',
              style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.purple),
            ),
          ),
        ],
      ),
    );
  }
}
