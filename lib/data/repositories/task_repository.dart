import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_client.dart';
import '../models/task.dart';

/// All tasks the current user can see (RLS-filtered server-side).
/// Hydrated with their assignment lists.
final myVisibleTasksProvider = FutureProvider<List<Task>>((ref) async {
  final rows = await sb
      .from('tasks')
      .select('*, task_assignments(assignee_type, assignee_id)')
      .order('due_date', ascending: true);

  return (rows as List).map((m) {
    final assignments =
        (m['task_assignments'] as List?) ?? const <dynamic>[];
    final userIds = <String>[];
    final committeeIds = <int>[];
    for (final a in assignments) {
      final type = a['assignee_type'] as String;
      final id = a['assignee_id'] as String;
      if (type == 'user') {
        userIds.add(id);
      } else if (type == 'committee') {
        committeeIds.add(int.parse(id));
      }
    }
    final t = Task.fromMap(m as Map<String, dynamic>);
    return Task(
      id: t.id,
      title: t.title,
      description: t.description,
      priority: t.priority,
      status: t.status,
      startDate: t.startDate,
      dueDate: t.dueDate,
      createdBy: t.createdBy,
      createdAt: t.createdAt,
      assigneeUserIds: userIds,
      assigneeCommitteeIds: committeeIds,
    );
  }).toList();
});

class TaskRepository {
  Future<String> createTask({
    required String title,
    String? description,
    required TaskPriority priority,
    DateTime? startDate,
    DateTime? dueDate,
    required List<String> assigneeUserIds,
    required List<int> assigneeCommitteeIds,
  }) async {
    final uid = sb.auth.currentUser!.id;
    final inserted = await sb
        .from('tasks')
        .insert({
          'title': title,
          'description': description,
          'priority': priority.name,
          'start_date': startDate?.toIso8601String().substring(0, 10),
          'due_date': dueDate?.toIso8601String().substring(0, 10),
          'created_by': uid,
        })
        .select('id')
        .single();
    final taskId = inserted['id'] as String;

    final assignments = [
      ...assigneeUserIds.map((u) => {
            'task_id': taskId,
            'assignee_type': 'user',
            'assignee_id': u,
          }),
      ...assigneeCommitteeIds.map((c) => {
            'task_id': taskId,
            'assignee_type': 'committee',
            'assignee_id': c.toString(),
          }),
    ];
    if (assignments.isNotEmpty) {
      await sb.from('task_assignments').insert(assignments);
    }
    return taskId;
  }

  Future<void> updateStatus(String taskId, TaskStatus status) =>
      sb.from('tasks').update({'status': statusToString(status)}).eq(
          'id', taskId);

  Future<void> deleteTask(String taskId) =>
      sb.from('tasks').delete().eq('id', taskId);

  /// Uploads `bytes` to the `attachments` bucket at
  /// `<taskId>/<timestamp>-<fileName>` and inserts a row into
  /// `task_attachments`. Throws if the file is over the 20MB limit.
  Future<TaskAttachment> uploadAttachment({
    required String taskId,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    const maxBytes = 20 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      throw Exception('حجم الملف يتجاوز ٢٠ ميجابايت');
    }
    final uid = sb.auth.currentUser!.id;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = fileName.replaceAll(RegExp(r'[^\w\-. ]'), '_');
    final path = '$taskId/$stamp-$safeName';

    await sb.storage.from('attachments').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: false,
          ),
        );

    final row = await sb
        .from('task_attachments')
        .insert({
          'task_id': taskId,
          'storage_path': path,
          'file_name': fileName,
          'file_size': bytes.length,
          'uploaded_by': uid,
        })
        .select()
        .single();
    return TaskAttachment.fromMap(row);
  }

  Future<void> deleteAttachment({
    required String attachmentId,
    required String storagePath,
  }) async {
    await sb.storage.from('attachments').remove([storagePath]);
    await sb.from('task_attachments').delete().eq('id', attachmentId);
  }

  /// Signed URL good for 5 minutes — used for downloads on web/mobile.
  Future<String> getAttachmentDownloadUrl(String storagePath) =>
      sb.storage.from('attachments').createSignedUrl(storagePath, 300);
}

final taskRepositoryProvider = Provider((_) => TaskRepository());

/// Attachments for a given task, refreshable after uploads/deletes.
final taskAttachmentsProvider =
    FutureProvider.family<List<TaskAttachment>, String>((ref, taskId) async {
  final rows = await sb
      .from('task_attachments')
      .select()
      .eq('task_id', taskId)
      .order('uploaded_at', ascending: false);
  return (rows as List)
      .map((m) => TaskAttachment.fromMap(m as Map<String, dynamic>))
      .toList();
});
