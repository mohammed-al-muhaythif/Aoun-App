import 'committee.dart';

/// Profile + all role assignments needed for permission checks and UI display.
class UserWithRoles {
  UserWithRoles({
    required this.id,
    required this.fullName,
    this.clubRole,
    this.committees = const [],
  });

  final String id;
  final String fullName;
  final String? clubRole; // president | vice_president | null
  final List<CommitteeMembership> committees;

  /// Best-effort display role label in Arabic.
  String get primaryRoleLabel {
    switch (clubRole) {
      case 'president':
        return 'رئيس النادي';
      case 'vice_president':
        return 'نائب رئيس النادي';
      case 'board_member':
        return 'مجلس الإدارة';
      case 'club_leader':
        return 'قائد الفريق';
      case 'club_vice_leader':
        return 'نائب قائد الفريق';
      case 'app_admin':
        return 'مدير النظام';
    }
    final head = committees.firstWhere(
      (c) => c.role == 'head' || c.role == 'vice_head',
      orElse: () => committees.isNotEmpty
          ? committees.first
          : CommitteeMembership(
              committeeId: 0,
              committeeNameAr: '',
              committeeNameEn: '',
              role: 'member',
            ),
    );
    switch (head.role) {
      case 'head':
        return 'قائد ${head.committeeNameAr}';
      case 'vice_head':
        return 'نائب قائد ${head.committeeNameAr}';
      default:
        return 'عضو ${head.committeeNameAr}';
    }
  }
}
