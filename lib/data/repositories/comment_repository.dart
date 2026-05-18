import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_client.dart';
import '../models/task.dart';

/// Realtime stream of comments for a task.
/// Uses Supabase channels to push new rows as they arrive.
final taskCommentsProvider =
    StreamProvider.family<List<TaskComment>, String>((ref, taskId) {
  final controller = StreamController<List<TaskComment>>();
  List<TaskComment> current = [];

  Future<void> refresh() async {
    final rows = await sb
        .from('task_comments')
        .select('*, profiles!inner(full_name)')
        .eq('task_id', taskId)
        .order('created_at', ascending: true);
    current = (rows as List).map((m) {
      final p = m['profiles'] as Map<String, dynamic>;
      return TaskComment(
        id: m['id'] as String,
        taskId: m['task_id'] as String,
        authorId: m['author_id'] as String,
        authorName: p['full_name'] as String,
        body: m['body'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
    }).toList();
    if (!controller.isClosed) controller.add(current);
  }

  refresh();

  final channel = sb
      .channel('comments:$taskId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'task_comments',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'task_id',
          value: taskId,
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

class CommentRepository {
  Future<void> addComment({required String taskId, required String body}) async {
    final uid = sb.auth.currentUser!.id;
    await sb.from('task_comments').insert({
      'task_id': taskId,
      'author_id': uid,
      'body': body,
    });
  }
}

final commentRepositoryProvider = Provider((_) => CommentRepository());
