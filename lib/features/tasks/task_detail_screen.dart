import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/formatters.dart';
import '../../core/localization/strings.dart';
import '../../core/permissions/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/task.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/comment_repository.dart';
import '../../data/repositories/committee_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/widgets/design_system.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/status_badge.dart';
import 'task_labels.dart';

/// Mockup-matched task detail (image 1, rightmost panel).
///
/// Layout (top to bottom):
///   • Purple gradient hero card with task title, status pill, and
///     delete/edit pill buttons in the corner
///   • "معلومات المهمة" info card with labelled rows
///   • "الوصف" prose section
///   • "تعليقات وملاحظات" with avatar comment cards + add-comment row
///   • "الملفات المرفقة" attachments table (UI scaffolded; upload in Phase 3)
class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId});
  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(myVisibleTasksProvider);
    final meAsync = ref.watch(currentUserProvider);
    final committeesAsync = ref.watch(committeesProvider);
    final membersAsync = ref.watch(allMembersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل المهمة')),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${S.error}: $e')),
        data: (all) {
          final task = all.where((t) => t.id == taskId).firstOrNull;
          if (task == null) return const EmptyState(message: S.noData);
          final perms = Permissions(meAsync.value);
          return _Body(
            task: task,
            perms: perms,
            committees: committeesAsync.valueOrNull ?? const [],
            members: membersAsync.valueOrNull ?? const [],
          );
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.task,
    required this.perms,
    required this.committees,
    required this.members,
  });

  final Task task;
  final Permissions perms;
  final List<dynamic> committees;  // Committee
  final List<dynamic> members;     // UserWithRoles

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(S.confirmDeleteTask),
        content: const Text(S.actionCannotUndone),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(S.cancel)),
          TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.statusOverdue),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(S.delete)),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(taskRepositoryProvider).deleteTask(task.id);
    ref.invalidate(myVisibleTasksProvider);
    if (context.mounted) context.pop();
  }

  /// Cancel (not delete) — flips status to `cancelled` so the task
  /// stays in the system but is marked as ملغاة.
  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد إلغاء المهمة'),
        content: const Text(
            'هل تريد إلغاء هذه المهمة؟ ستبقى في السجل لكنها ستُعلَّم كملغاة.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(S.cancel)),
          TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.statusOverdue),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('إلغاء المهمة')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(taskRepositoryProvider)
          .updateStatus(task.id, TaskStatus.cancelled);
      ref.invalidate(myVisibleTasksProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء المهمة')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${S.error}: $e')));
    }
    return;
  }

  String _resolveAssignee() {
    if (task.assigneeUserIds.isNotEmpty) {
      final id = task.assigneeUserIds.first;
      final m = members.where((m) => m.id == id).firstOrNull;
      if (m != null) return m.fullName as String;
    }
    if (task.assigneeCommitteeIds.isNotEmpty) {
      final cid = task.assigneeCommitteeIds.first;
      final c = committees.where((c) => c.id == cid).firstOrNull;
      if (c != null) return 'أعضاء ${c.nameAr}';
    }
    return '—';
  }

  String _committeeLabel() => taskCommitteeLabel(task, committees, members);
  String _creatorName() => taskCreatorName(task, members);

  /// Prominent committee chip shown on the (purple) hero so the committee —
  /// or "مهمة عامة" — is obvious at the top of the task.
  Widget _heroCommitteeChip() {
    final label = _committeeLabel();
    final general = label == 'مهمة عامة';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(general ? Icons.public : Icons.groups_outlined,
            size: 14, color: Colors.white),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.cairo(
                fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canDelete = perms.canDeleteTask(
      taskCommitteeIds: task.assigneeCommitteeIds,
      createdBy: task.createdBy,
    );
    final canCancel = perms.canCancelTask(
      taskCommitteeIds: task.assigneeCommitteeIds,
      createdBy: task.createdBy,
    );
    final isAlreadyCancelled = task.status == TaskStatus.cancelled;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradientHero(
            title: task.title,
            subtitle: 'تفاصيل المهمة',
            actions: [
              if (canDelete)
                PillButton.outlined(
                  label: S.delete,
                  onPressed: () => _confirmDelete(context, ref),
                ),
              if (canCancel && !isAlreadyCancelled)
                PillButton.outlined(
                  label: 'إلغاء',
                  onPressed: () => _confirmCancel(context, ref),
                ),
            ],
            bottom: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusBadge(status: task.status),
                PriorityBadge(priority: task.priority),
                _heroCommitteeChip(),
              ],
            ),
          ),
          const SectionTitle('معلومات المهمة'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                InfoRow(
                  label: 'الحالة',
                  value: switch (task.status) {
                    TaskStatus.pending => S.statusPending,
                    TaskStatus.inProgress => S.statusInProgress,
                    TaskStatus.completed => S.statusCompleted,
                    TaskStatus.overdue => S.statusOverdue,
                    TaskStatus.cancelled => S.statusCancelled,
                  },
                  valueColor: statusColor(task.status),
                ),
                InfoRow(
                  label: 'الأولوية',
                  value: switch (task.priority) {
                    TaskPriority.high => S.priorityHigh,
                    TaskPriority.medium => S.priorityMedium,
                    TaskPriority.low => S.priorityLow,
                  },
                  valueColor: switch (task.priority) {
                    TaskPriority.high => AppColors.priorityHigh,
                    TaskPriority.medium => AppColors.priorityMedium,
                    TaskPriority.low => AppColors.priorityLow,
                  },
                ),
                InfoRow(
                    label: S.startDate,
                    value: formatArabicDate(task.startDate)),
                InfoRow(
                    label: S.dueDate,
                    value: formatArabicDate(task.dueDate),
                    valueColor: task.status == TaskStatus.overdue
                        ? AppColors.statusOverdue
                        : null),
                InfoRow(label: 'المسؤول', value: _resolveAssignee()),
                InfoRow(label: 'اللجنة', value: _committeeLabel()),
                InfoRow(label: 'أنشأها', value: _creatorName()),
              ],
            ),
          ),
          if (task.description != null && task.description!.trim().isNotEmpty) ...[
            const SectionTitle('الوصف'),
            AppCard(
              child: Text(
                task.description!,
                style: GoogleFonts.cairo(
                    height: 1.6, fontSize: 13, color: AppColors.textPrimary),
              ),
            ),
          ],
          // Status-change chips for assignees. RLS policy
          // "tasks: assignees can update status" allows this for any
          // user/committee assignee — we mirror that gate client-side.
          if (_canChangeStatus(task, perms)) ...[
            const SectionTitle('تغيير حالة المهمة'),
            _StatusPicker(task: task),
          ],
          const SizedBox(height: 8),
          _CommentsSection(taskId: task.id),
          _AttachmentsSection(taskId: task.id),
        ],
      ),
    );
  }
}

bool _canChangeStatus(Task t, Permissions perms) {
  final me = perms.me;
  if (me == null) return false;
  if (perms.isPresident) return true;
  if (t.createdBy == me.id) return true;
  if (t.assigneeUserIds.contains(me.id)) return true;
  // Member of an assigned committee → also allowed.
  final myCommitteeIds = me.committees.map((c) => c.committeeId).toSet();
  return t.assigneeCommitteeIds.any(myCommitteeIds.contains);
}

class _StatusPicker extends ConsumerStatefulWidget {
  const _StatusPicker({required this.task});
  final Task task;
  @override
  ConsumerState<_StatusPicker> createState() => _StatusPickerState();
}

class _StatusPickerState extends ConsumerState<_StatusPicker> {
  bool _saving = false;

  Future<void> _set(TaskStatus s) async {
    if (s == widget.task.status || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(taskRepositoryProvider).updateStatus(widget.task.id, s);
      ref.invalidate(myVisibleTasksProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${S.error}: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = <(TaskStatus, String, Color)>[
      (TaskStatus.pending, S.statusPending, AppColors.statusPending),
      (TaskStatus.inProgress, S.statusInProgress, AppColors.statusInProgress),
      (TaskStatus.completed, S.statusCompleted, AppColors.statusCompleted),
    ];
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: _saving ? null : () => _set(options[i].$1),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: widget.task.status == options[i].$1
                        ? options[i].$3.withValues(alpha: 0.15)
                        : Colors.transparent,
                    border: Border.all(
                      color: widget.task.status == options[i].$1
                          ? options[i].$3
                          : AppColors.border,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    options[i].$2,
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: widget.task.status == options[i].$1
                          ? options[i].$3
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CommentsSection extends ConsumerStatefulWidget {
  const _CommentsSection({required this.taskId});
  final String taskId;
  @override
  ConsumerState<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<_CommentsSection> {
  final _controller = TextEditingController();
  bool _sending = false;
  bool _showInput = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(commentRepositoryProvider)
          .addComment(taskId: widget.taskId, body: text);
      _controller.clear();
      setState(() => _showInput = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${S.error}: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(taskCommentsProvider(widget.taskId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'تعليقات وملاحظات',
          trailing: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.purple,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              textStyle:
                  GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            onPressed: () => setState(() => _showInput = !_showInput),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('إضافة تعليق'),
          ),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: commentsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('${S.error}: $e'),
            data: (comments) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'لا توجد تعليقات بعد',
                        style: GoogleFonts.cairo(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                    )
                  else
                    ...comments.map((c) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InitialAvatar(name: c.authorName, radius: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Text(c.authorName,
                                          style: GoogleFonts.cairo(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13)),
                                      const SizedBox(width: 6),
                                      Text(formatRelativeArabic(c.createdAt),
                                          style: GoogleFonts.cairo(
                                              fontSize: 11,
                                              color:
                                                  AppColors.textSecondary)),
                                    ]),
                                    const SizedBox(height: 2),
                                    Text(c.body,
                                        style: GoogleFonts.cairo(
                                            fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                  if (_showInput) ...[
                    const Divider(height: 24),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              hintText: 'اكتب تعليقاً…'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.purple,
                          foregroundColor: Colors.white,
                        ),
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send),
                        onPressed: _sending ? null : _send,
                      ),
                    ]),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AttachmentsSection extends ConsumerStatefulWidget {
  const _AttachmentsSection({required this.taskId});
  final String taskId;
  @override
  ConsumerState<_AttachmentsSection> createState() =>
      _AttachmentsSectionState();
}

class _AttachmentsSectionState extends ConsumerState<_AttachmentsSection> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'xlsx', 'zip', 'docx', 'txt'],
    );
    if (res == null) return;
    const maxBytes = 20 * 1024 * 1024;
    setState(() => _uploading = true);
    try {
      final repo = ref.read(taskRepositoryProvider);
      for (final f in res.files) {
        if (f.size > maxBytes) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${f.name}: حجم الملف يتجاوز ٢٠ ميجابايت')));
          continue;
        }
        final bytes = f.bytes;
        if (bytes == null) continue;
        await repo.uploadAttachment(
          taskId: widget.taskId,
          fileName: f.name,
          bytes: bytes,
        );
      }
      ref.invalidate(taskAttachmentsProvider(widget.taskId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${S.error}: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _download(TaskAttachment a) async {
    try {
      final url = await ref
          .read(taskRepositoryProvider)
          .getAttachmentDownloadUrl(a.storagePath);
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${S.error}: $e')));
    }
  }

  Future<void> _delete(TaskAttachment a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المرفق'),
        content: const Text(S.actionCannotUndone),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(S.cancel)),
          TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.statusOverdue),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(S.delete)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(taskRepositoryProvider)
          .deleteAttachment(attachmentId: a.id, storagePath: a.storagePath);
      ref.invalidate(taskAttachmentsProvider(widget.taskId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${S.error}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final attsAsync = ref.watch(taskAttachmentsProvider(widget.taskId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'الملفات المرفقة',
          trailing: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.purple,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              textStyle: GoogleFonts.cairo(
                  fontWeight: FontWeight.w700, fontSize: 12),
            ),
            onPressed: _uploading ? null : _pickAndUpload,
            icon: _uploading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.purple),
                  )
                : const Icon(Icons.attach_file, size: 14),
            label: const Text('إرفاق ملف'),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: attsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('${S.error}: $e'),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('لا توجد مرفقات بعد',
                        style: GoogleFonts.cairo(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                      ),
                    ),
                    child: Row(children: [
                      _attCol('اسم الملف', flex: 4),
                      _attCol('الحجم', flex: 2),
                      _attCol('التاريخ', flex: 2),
                      _attCol('رابط', flex: 2),
                    ]),
                  ),
                  for (var i = 0; i < rows.length; i++)
                    _AttachmentTableRow(
                      attachment: rows[i],
                      onDownload: () => _download(rows[i]),
                      onDelete: () => _delete(rows[i]),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

Widget _attCol(String s, {required int flex}) => Expanded(
      flex: flex,
      child: Text(
        s,
        style: GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary),
      ),
    );

String _attFmtBytes(int b) {
  if (b < 1024) return '$b بايت';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
}

IconData _attIconFor(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.pdf')) return Icons.picture_as_pdf;
  if (n.endsWith('.png') ||
      n.endsWith('.jpg') ||
      n.endsWith('.jpeg') ||
      n.endsWith('.webp')) {
    return Icons.image_outlined;
  }
  if (n.endsWith('.zip')) return Icons.folder_zip_outlined;
  if (n.endsWith('.xlsx') || n.endsWith('.xls')) return Icons.table_chart_outlined;
  if (n.endsWith('.docx') || n.endsWith('.doc')) return Icons.description_outlined;
  return Icons.insert_drive_file_outlined;
}

class _AttachmentTableRow extends StatelessWidget {
  const _AttachmentTableRow({
    required this.attachment,
    required this.onDownload,
    required this.onDelete,
  });
  final TaskAttachment attachment;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        Expanded(
          flex: 4,
          child: Row(children: [
            Icon(_attIconFor(attachment.fileName),
                color: AppColors.purple, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                attachment.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
            ),
          ]),
        ),
        Expanded(
          flex: 2,
          child: Text(_attFmtBytes(attachment.fileSize),
              style: GoogleFonts.cairo(
                  fontSize: 12, color: AppColors.textPrimary)),
        ),
        Expanded(
          flex: 2,
          child: Text(formatArabicDateShort(attachment.uploadedAt),
              style: GoogleFonts.cairo(
                  fontSize: 12, color: AppColors.textPrimary)),
        ),
        Expanded(
          flex: 2,
          child: Row(children: [
            InkWell(
              onTap: onDownload,
              child: Text(
                'تنزيل',
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.purple,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.purple),
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: onDelete,
              child: const Icon(Icons.delete_outline,
                  color: AppColors.statusOverdue, size: 16),
            ),
          ]),
        ),
      ]),
    );
  }
}
