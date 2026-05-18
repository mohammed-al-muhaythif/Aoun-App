import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_client.dart';
import '../models/notification.dart';
import 'auth_repository.dart';

/// Realtime stream of notifications for the current user.
final notificationsProvider =
    StreamProvider<List<AppNotification>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) {
    return Stream.value(const <AppNotification>[]);
  }

  final controller = StreamController<List<AppNotification>>();
  List<AppNotification> current = [];

  Future<void> refresh() async {
    final rows = await sb
        .from('notifications')
        .select()
        .eq('recipient_id', uid)
        .order('created_at', ascending: false)
        .limit(100);
    current = (rows as List)
        .map((m) =>
            AppNotification.fromMap(m as Map<String, dynamic>))
        .toList();
    if (!controller.isClosed) controller.add(current);
  }

  refresh();

  final channel = sb
      .channel('notifications:$uid')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'recipient_id',
          value: uid,
        ),
        callback: (_) => refresh(),
      )
      .subscribe();

  ref.onDispose(() {
    sb.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});

final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).when(
        data: (list) => list.where((n) => !n.isRead).length,
        loading: () => 0,
        error: (_, _) => 0,
      );
});

class NotificationRepository {
  Future<void> markRead(String id) =>
      sb.from('notifications').update({'is_read': true}).eq('id', id);

  Future<void> markAllRead() {
    final uid = sb.auth.currentUser!.id;
    return sb
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient_id', uid)
        .eq('is_read', false);
  }
}

final notificationRepositoryProvider =
    Provider((_) => NotificationRepository());
