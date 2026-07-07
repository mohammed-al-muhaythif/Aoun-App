import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/localization/formatters.dart';
import '../../core/localization/strings.dart';
import '../../core/permissions/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/committee.dart';
import '../../data/models/task.dart';
import '../../data/models/user_with_roles.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/committee_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/widgets/design_system.dart';

/// Mockup #5 (image 1, leftmost panel) — "نموذج إنشاء مهمة".
/// Purple title bar, white card with two-column rows for the short
/// fields (priority + name, dates), description full-width, assignee
/// pickers, dual buttons at the bottom (إنشاء المهمة + إلغاء).
class CreateTaskScreen extends ConsumerStatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  ConsumerState<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends ConsumerState<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  TaskPriority? _priority;
  DateTime? _start;
  DateTime? _due;
  final Set<String> _userIds = {};
  final Set<int> _committeeIds = {};
  final List<PlatformFile> _pickedFiles = [];
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'xlsx', 'zip', 'docx', 'txt'],
    );
    if (result == null) return;
    const maxBytes = 20 * 1024 * 1024;
    final oversize = result.files.where((f) => (f.size) > maxBytes).toList();
    if (oversize.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'تم تجاهل ${oversize.length} ملف لتجاوز ٢٠ ميجابايت')));
    }
    setState(() {
      _pickedFiles.addAll(result.files.where((f) => f.size <= maxBytes));
    });
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      locale: const Locale('ar'),
    );
    if (picked != null) {
      setState(() => isStart ? _start = picked : _due = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _priority == null) return;
    if (_userIds.isEmpty && _committeeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر مُعيَّناً واحداً على الأقل')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(taskRepositoryProvider);
      final taskId = await repo.createTask(
        title: _name.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        priority: _priority!,
        startDate: _start,
        dueDate: _due,
        assigneeUserIds: _userIds.toList(),
        assigneeCommitteeIds: _committeeIds.toList(),
      );
      // Track partial-upload failures so we can surface them without
      // orphaning the task (which is already created at this point).
      final failed = <String>[];
      for (final f in _pickedFiles) {
        final bytes = f.bytes;
        if (bytes == null) {
          failed.add(f.name);
          continue;
        }
        try {
          await repo.uploadAttachment(
            taskId: taskId,
            fileName: f.name,
            bytes: bytes,
          );
        } catch (_) {
          failed.add(f.name);
        }
      }
      ref.invalidate(myVisibleTasksProvider);
      if (!mounted) return;
      if (failed.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'تم إنشاء المهمة، لكن فشل رفع ${failed.length} ملف. يمكنك إضافتها من شاشة تفاصيل المهمة.')));
      }
      context.pop();
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
    final meAsync = ref.watch(currentUserProvider);
    final committeesAsync = ref.watch(committeesProvider);
    final membersAsync = ref.watch(allMembersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('نموذج إنشاء مهمة')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Row 1: priority + name
                  Row(children: [
                    Expanded(
                      child: _LabelledChild(
                        label: 'الأولوية',
                        child: DropdownButtonFormField<TaskPriority>(
                          initialValue: _priority,
                          hint: Text('اختر الأولوية',
                              style: GoogleFonts.cairo(fontSize: 13)),
                          items: const [
                            DropdownMenuItem(
                                value: TaskPriority.high,
                                child: Text(S.priorityHigh)),
                            DropdownMenuItem(
                                value: TaskPriority.medium,
                                child: Text(S.priorityMedium)),
                            DropdownMenuItem(
                                value: TaskPriority.low,
                                child: Text(S.priorityLow)),
                          ],
                          onChanged: (v) => setState(() => _priority = v),
                          validator: (v) => v == null ? S.required : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LabelledChild(
                        label: 'اسم المهمة',
                        child: TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                              hintText: 'أدخل اسم المهمة'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? S.required
                                  : null,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  // Row 2: start + due dates
                  Row(children: [
                    Expanded(
                      child: _LabelledChild(
                        label: S.startDate,
                        child: _DateField(
                            date: _start, onTap: () => _pickDate(true)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LabelledChild(
                        label: S.dueDate,
                        child: _DateField(
                            date: _due, onTap: () => _pickDate(false)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _LabelledChild(
                    label: 'الوصف',
                    child: TextFormField(
                      controller: _description,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'أدخل وصف المهمة بالتفصيل…',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _LabelledChild(
                    label: 'المرفقات',
                    child: _AttachmentsPicker(
                      files: _pickedFiles,
                      onAdd: _pickAttachments,
                      onRemove: (i) =>
                          setState(() => _pickedFiles.removeAt(i)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Assignee block — committees then members
                  Row(children: [
                    Expanded(
                      child: _LabelledChild(
                        label: 'اللجنة / الفريق',
                        child: committeesAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('${S.error}: $e'),
                          data: (cs) => meAsync.maybeWhen(
                            data: (me) {
                              final perms = Permissions(me);
                              final allowed = perms.isPresident
                                  ? cs
                                  : cs
                                      .where((c) =>
                                          perms.isCommitteeHead(c.id))
                                      .toList();
                              return _CommitteeChips(
                                committees: allowed,
                                selected: _committeeIds,
                                onChanged: (s) => setState(() {
                                  _committeeIds
                                    ..clear()
                                    ..addAll(s);
                                }),
                              );
                            },
                            orElse: () => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LabelledChild(
                        label: 'تعيين إلى',
                        child: membersAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('${S.error}: $e'),
                          data: (members) => meAsync.maybeWhen(
                            data: (me) {
                              final perms = Permissions(me);
                              final allowed = perms.isPresident
                                  ? members
                                  : members
                                      .where((u) => u.committees.any(
                                          (c) => perms.isCommitteeHead(
                                              c.committeeId)))
                                      .toList();
                              return _MemberSearchPicker(
                                members: allowed,
                                selected: _userIds,
                                onChanged: (s) => setState(() {
                                  _userIds
                                    ..clear()
                                    ..addAll(s);
                                }),
                              );
                            },
                            orElse: () => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('إنشاء المهمة'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    foregroundColor: AppColors.textPrimary,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: GoogleFonts.cairo(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  onPressed: _saving ? null : () => context.pop(),
                  child: const Text(S.cancel),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _AttachmentsPicker extends StatelessWidget {
  const _AttachmentsPicker({
    required this.files,
    required this.onAdd,
    required this.onRemove,
  });
  final List<PlatformFile> files;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (files.isNotEmpty) ...[
          for (var i = 0; i < files.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                const Icon(Icons.insert_drive_file_outlined,
                    color: AppColors.purple, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    files[i].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(fontSize: 12),
                  ),
                ),
                Text(_fmtBytes(files[i].size),
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: AppColors.textSecondary)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close,
                      size: 16, color: AppColors.statusOverdue),
                  onPressed: () => onRemove(i),
                ),
              ]),
            ),
        ],
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.attach_file, size: 18),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.border),
            foregroundColor: AppColors.purple,
            minimumSize: const Size.fromHeight(42),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle:
                GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          label: const Text('إرفاق ملف'),
        ),
      ],
    );
  }

  String _fmtBytes(int b) {
    if (b < 1024) return '$b بايت';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} كيلوبايت';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} ميجابايت';
  }
}

class _LabelledChild extends StatelessWidget {
  const _LabelledChild({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, right: 2),
          child: Text(label,
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        child,
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap});
  final DateTime? date;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(hintText: 'mm/dd/yyyy'),
        child: Text(date == null ? 'mm/dd/yyyy' : formatArabicDate(date),
            style: GoogleFonts.cairo(
                fontSize: 13,
                color: date == null
                    ? AppColors.textSecondary
                    : AppColors.textPrimary)),
      ),
    );
  }
}

class _CommitteeChips extends StatelessWidget {
  const _CommitteeChips({
    required this.committees,
    required this.selected,
    required this.onChanged,
  });
  final List<Committee> committees;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    if (committees.isEmpty) {
      return Text('—',
          style: GoogleFonts.cairo(color: AppColors.textSecondary));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: committees.map((c) {
        final isSel = selected.contains(c.id);
        return FilterChip(
          selected: isSel,
          label: Text(c.nameAr, style: GoogleFonts.cairo(fontSize: 12)),
          selectedColor: AppColors.purpleLight,
          checkmarkColor: AppColors.purple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
                color: isSel ? AppColors.purple : AppColors.border),
          ),
          backgroundColor: Colors.white,
          onSelected: (v) {
            final next = {...selected};
            v ? next.add(c.id) : next.remove(c.id);
            onChanged(next);
          },
        );
      }).toList(),
    );
  }
}

class _MemberSearchPicker extends StatefulWidget {
  const _MemberSearchPicker({
    required this.members,
    required this.selected,
    required this.onChanged,
  });
  final List<UserWithRoles> members;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<_MemberSearchPicker> createState() => _MemberSearchPickerState();
}

class _MemberSearchPickerState extends State<_MemberSearchPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    if (widget.members.isEmpty) {
      return Text('لا أعضاء',
          style: GoogleFonts.cairo(color: AppColors.textSecondary));
    }
    final filtered = _query.isEmpty
        ? widget.members
        : widget.members
            .where((m) => m.fullName.contains(_query))
            .toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(6),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 18),
                hintText: 'ابحث عن عضو…',
                isDense: true,
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView(
              shrinkWrap: true,
              children: filtered.map((m) {
                final isSel = widget.selected.contains(m.id);
                return CheckboxListTile(
                  value: isSel,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.purple,
                  dense: true,
                  title: Text(m.fullName,
                      style: GoogleFonts.cairo(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  subtitle: Text(m.primaryRoleLabel,
                      style: GoogleFonts.cairo(
                          fontSize: 10, color: AppColors.textSecondary)),
                  onChanged: (v) {
                    final next = {...widget.selected};
                    v == true ? next.add(m.id) : next.remove(m.id);
                    widget.onChanged(next);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
