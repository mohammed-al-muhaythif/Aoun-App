import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/strings.dart';
import '../../core/permissions/permissions.dart';
import '../../data/repositories/auth_repository.dart';
import '../../shared/widgets/empty_state.dart';
import 'committee_dashboard.dart';
import 'member_dashboard.dart';

/// Picks the dashboard variant based on role:
/// - Full admins (president/board/club_leader/app_admin/...) → member dashboard
/// - A committee head/vice-head → committee dashboard
/// - Everyone else → member dashboard
///
/// No AppBar is shown — each dashboard owns its full-bleed greeting
/// bar / gradient hero (per mockup #2 and #3).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(currentUserProvider);

    return Scaffold(
      body: SafeArea(
        child: meAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('${S.error}: $e')),
          data: (me) {
            if (me == null) return const EmptyState(message: S.error);
            final perms = Permissions(me);

            // Find a committee where this user is head/vice_head — null-safe.
            final headship = me.committees
                .where((c) => c.role == 'head' || c.role == 'vice_head')
                .firstOrNull;

            // Show committee dashboard only when we actually have a
            // leadership committee AND the user isn't a club-wide admin.
            if (!perms.isPresident && headship != null) {
              return CommitteeDashboard(perms: perms, committee: headship);
            }
            return MemberDashboard(perms: perms);
          },
        ),
      ),
    );
  }
}
