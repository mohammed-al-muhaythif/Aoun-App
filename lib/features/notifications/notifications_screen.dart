import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/localization/formatters.dart';
import '../../core/localization/strings.dart';
import '../../core/permissions/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/notification.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../shared/widgets/design_system.dart';
import '../../shared/widgets/empty_state.dart';

/// Mockup #6 (image 1, middle panel) — "صفحة الإشعارات".
/// Two sections: "إشعارات جديدة" (with red unread-count badge) and
/// "إشعارات سابقة". Each row: tinted-circle icon + title + body + time.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final meAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationRepositoryProvider).markAllRead();
              // Belt-and-suspenders: realtime fires for the UPDATE,
              // but an explicit invalidate guarantees the badge clears
              // immediately even if the channel is slow to reconnect.
              ref.invalidate(notificationsProvider);
            },
            child: Text('تحديث الكل',
                style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
          meAsync.maybeWhen(
            data: (me) {
              final perms = Permissions(me);
              if (!perms.canSendManualNotification) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.campaign),
                tooltip: 'إرسال إشعار',
                onPressed: () => context.push('/notifications/compose'),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${S.error}: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
                message: 'لا توجد إشعارات', icon: Icons.notifications_off);
          }
          final unread = list.where((n) => !n.isRead).toList();
          final read = list.where((n) => n.isRead).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (unread.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'إشعارات جديدة',
                    badgeCount: unread.length,
                  ),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                        children: unread
                            .map((n) => _Row(n: n, isLast: n == unread.last))
                            .toList()),
                  ),
                  const SizedBox(height: 8),
                ],
                if (read.isNotEmpty) ...[
                  const _SectionHeader(title: 'إشعارات سابقة'),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                        children: read
                            .map((n) => _Row(n: n, isLast: n == read.last))
                            .toList()),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.badgeCount});
  final String title;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(children: [
        Text(title,
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(width: 8),
        if (badgeCount != null && badgeCount! > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.statusOverdue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$badgeCount',
                style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ),
      ]),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.n, required this.isLast});
  final AppNotification n;
  final bool isLast;

  IconData get _icon => switch (n.type) {
        'task_assigned' => Icons.assignment_outlined,
        'task_completed' => Icons.check_circle_outline,
        'task_overdue' => Icons.warning_amber_outlined,
        'comment_added' => Icons.chat_bubble_outline,
        'hours_logged' => Icons.access_time,
        'member_added' => Icons.person_add_outlined,
        'manual' => Icons.campaign_outlined,
        _ => Icons.notifications_outlined,
      };

  Color get _color => switch (n.type) {
        'task_overdue' => AppColors.statusOverdue,
        'task_completed' => AppColors.statusCompleted,
        'task_assigned' => AppColors.statusInProgress,
        _ => AppColors.purple,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        if (!n.isRead) {
          await ref.read(notificationRepositoryProvider).markRead(n.id);
        }
        if (!context.mounted) return;
        if (n.relatedId != null) {
          switch (n.type) {
            case 'task_assigned':
            case 'task_completed':
            case 'task_overdue':
            case 'comment_added':
              context.push('/tasks/${n.relatedId}');
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isLast ? Colors.transparent : AppColors.border,
            ),
          ),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(_icon, color: _color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.title,
                    style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight:
                            n.isRead ? FontWeight.w500 : FontWeight.w700)),
                const SizedBox(height: 2),
                Text(n.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(formatRelativeArabic(n.createdAt),
              style: GoogleFonts.cairo(
                  fontSize: 10, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}
