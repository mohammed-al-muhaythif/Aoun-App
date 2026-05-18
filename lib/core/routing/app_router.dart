import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/hours/hr_leaderboard_screen.dart';
import '../../features/hours/log_hours_screen.dart';
import '../../features/hours/my_hours_screen.dart';
import '../../features/members/member_profile_screen.dart';
import '../../features/members/members_directory_screen.dart';
import '../../features/notifications/compose_notification_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/tasks/create_task_screen.dart';
import '../../features/tasks/task_detail_screen.dart';
import '../../features/tasks/task_list_screen.dart';
import '../../features/teams/create_team_screen.dart';
import '../../features/teams/team_dashboard_screen.dart';
import '../../features/teams/teams_list_screen.dart';
import '../supabase/supabase_client.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthed = sb.auth.currentUser != null;
      final loggingIn = state.matchedLocation == '/login';
      // Guest mode: tasks listing accessible without auth via ?guest=1
      final isGuestTasks = state.matchedLocation == '/tasks' &&
          state.uri.queryParameters['guest'] == '1';

      if (!isAuthed && !loggingIn && !isGuestTasks) return '/login';
      if (isAuthed && loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/',
        builder: (_, _) => const MainShell(child: DashboardScreen()),
      ),
      GoRoute(
        path: '/tasks',
        builder: (_, _) => const MainShell(child: TaskListScreen()),
      ),
      GoRoute(
        path: '/tasks/new',
        builder: (_, _) => const CreateTaskScreen(),
      ),
      GoRoute(
        path: '/tasks/:id',
        builder: (_, s) => TaskDetailScreen(taskId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/teams',
        builder: (_, _) => const MainShell(child: TeamsListScreen()),
      ),
      GoRoute(
        path: '/teams/new',
        builder: (_, _) => const CreateTeamScreen(),
      ),
      GoRoute(
        path: '/teams/:id',
        builder: (_, s) => MainShell(
          child: TeamDashboardScreen(teamId: s.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/hours',
        builder: (_, _) => const MainShell(child: MyHoursScreen()),
      ),
      GoRoute(
        path: '/hours/log',
        builder: (_, _) => const LogHoursScreen(),
      ),
      GoRoute(
        path: '/leaderboard',
        builder: (_, _) => const HrLeaderboardScreen(),
      ),
      GoRoute(
        path: '/committees/:id/hours',
        builder: (_, s) => HrLeaderboardScreen(
          committeeId: int.parse(s.pathParameters['id']!),
          title: s.uri.queryParameters['name'],
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/notifications/compose',
        builder: (_, _) => const ComposeNotificationScreen(),
      ),
      GoRoute(
        path: '/members',
        builder: (_, _) => const MainShell(child: MembersDirectoryScreen()),
      ),
      GoRoute(
        path: '/members/:id',
        builder: (_, s) =>
            MemberProfileScreen(memberId: s.pathParameters['id']!),
      ),
    ],
  );
});

/// Bottom navigation shell shared across top-level tabs.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});
  final Widget child;

  static const _routes = ['/', '/tasks', '/hours', '/teams', '/members'];

  int _indexFor(String loc) {
    for (var i = _routes.length - 1; i >= 0; i--) {
      if (loc.startsWith(_routes[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final idx = _indexFor(loc);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => context.go(_routes[i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.task_alt), label: 'المهام'),
          NavigationDestination(
              icon: Icon(Icons.access_time), label: 'ساعاتي'),
          NavigationDestination(icon: Icon(Icons.groups), label: 'الفِرَق'),
          NavigationDestination(icon: Icon(Icons.people), label: 'الأعضاء'),
        ],
      ),
    );
  }
}
