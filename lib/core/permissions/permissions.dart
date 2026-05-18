import '../../data/models/user_with_roles.dart';

/// UI-side permission checks. Must mirror RLS in
/// supabase/migrations/0002_rls_policies.sql.
/// Server is authoritative — these only hide UI affordances.
class Permissions {
  Permissions(this.me);
  final UserWithRoles? me;

  bool get isAuthed => me != null;

  /// True for any role with full-admin permissions:
  /// president, vice_president, board_member, club_leader,
  /// club_vice_leader, or app_admin.
  bool get isPresident {
    const adminRoles = {
      'president',
      'vice_president',
      'board_member',
      'club_leader',
      'club_vice_leader',
      'app_admin',
    };
    return me?.clubRole != null && adminRoles.contains(me!.clubRole);
  }

  bool isCommitteeHead(int committeeId) =>
      me?.committees.any((c) =>
          c.committeeId == committeeId &&
          (c.role == 'head' || c.role == 'vice_head')) ??
      false;

  bool get isAnyCommitteeHead =>
      me?.committees
          .any((c) => c.role == 'head' || c.role == 'vice_head') ??
      false;

  bool get isInHr =>
      me?.committees.any((c) => c.committeeNameEn == 'Human Resources') ??
      false;

  bool get isHrHead =>
      me?.committees.any((c) =>
          c.committeeNameEn == 'Human Resources' &&
          (c.role == 'head' || c.role == 'vice_head')) ??
      false;

  // ─── tasks ─────────────────────────────────────────────────────────
  bool get canCreateTask => isAnyCommitteeHead || isPresident;
  bool canDeleteTask({required Iterable<int> taskCommitteeIds}) =>
      isPresident || taskCommitteeIds.any(isCommitteeHead);

  // ─── members / committees ─────────────────────────────────────────
  bool canManageCommittee(int committeeId) =>
      isPresident || isCommitteeHead(committeeId);

  // ─── volunteer hours ──────────────────────────────────────────────
  bool canEditHoursOf(UserWithRoles target) {
    if (me == null) return false;
    if (me!.id == target.id) return true;
    if (isPresident || isHrHead) return true;
    // committee_head of any committee target is in
    return target.committees.any((tc) => isCommitteeHead(tc.committeeId));
  }

  bool canViewCommitteeHours(int committeeId) =>
      isPresident || isInHr || isCommitteeHead(committeeId);

  bool get canViewLeaderboards => isPresident || isInHr;

  // ─── notifications ────────────────────────────────────────────────
  // Must mirror server-side check in `supabase/functions/send-push/index.ts`:
  //   - any club_role admin
  //   - any committee head / vice_head
  //   - any Technology committee member
  bool get canSendManualNotification {
    if (isPresident || isAnyCommitteeHead) return true;
    return me?.committees.any((c) => c.committeeNameEn == 'Technology') ??
        false;
  }
}
