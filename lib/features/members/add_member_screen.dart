import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/localization/strings.dart';
import '../../core/permissions/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/committee_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../shared/widgets/design_system.dart';
import '../../shared/widgets/empty_state.dart';

/// Add a brand-new club member. Calls the `add_member` SQL RPC which
/// creates the auth user + profile + committee membership atomically.
///
/// Permission gate (mirrors RPC):
///   * Committee head of `committeeId` → can add with role member/vice_head
///   * HR head / admin → can add with any role (member/vice_head/head),
///     to any committee (committee picker shown).
class AddMemberScreen extends ConsumerStatefulWidget {
  const AddMemberScreen({
    super.key,
    required this.committeeId,
    this.committeeName,
  });
  final int committeeId;
  final String? committeeName;

  @override
  ConsumerState<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends ConsumerState<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _uni = TextEditingController();
  final _major = TextEditingController();
  late int _committeeId;
  String _role = 'member';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _committeeId = widget.committeeId;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _uni.dispose();
    _major.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(committeeRepositoryProvider).addNewMember(
            fullName: _name.text.trim(),
            universityId: _uni.text.trim(),
            phone: _phone.text.trim(),
            major: _major.text.trim().isEmpty ? null : _major.text.trim(),
            committeeId: _committeeId,
            role: _role,
          );
      ref.invalidate(allMembersProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت إضافة العضو بنجاح')));
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
    final perms = Permissions(meAsync.value);
    final isHrOrAdmin = perms.isPresident || perms.isHrHead;
    final committeesAsync = ref.watch(committeesProvider);

    if (!perms.canManageCommittee(widget.committeeId)) {
      return Scaffold(
        appBar: AppBar(title: const Text('إضافة عضو جديد')),
        body: const EmptyState(
            message: 'لا تملك صلاحية إضافة أعضاء',
            icon: Icons.lock_outline),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('إضافة عضو جديد'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LabelledField(
                    label: 'الاسم الكامل *',
                    child: TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                          hintText: 'مثال: أحمد محمد العتيبي'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? S.required
                          : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: _LabelledField(
                        label: 'الرقم الجامعي *',
                        child: TextFormField(
                          controller: _uni,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: const InputDecoration(
                              hintText: '4XXXXXXXX'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return S.required;
                            }
                            if (v.trim().length < 6) {
                              return 'رقم غير صالح';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LabelledField(
                        label: 'رقم الجوال *',
                        child: TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9+ ]')),
                          ],
                          decoration: const InputDecoration(
                              hintText: '05XXXXXXXX'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return S.required;
                            }
                            final digits = v.replaceAll(RegExp(r'\D'), '');
                            if (digits.length < 9) return 'رقم غير صالح';
                            return null;
                          },
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _LabelledField(
                    label: 'التخصص الدراسي (اختياري)',
                    child: TextFormField(
                      controller: _major,
                      decoration: const InputDecoration(
                          hintText: 'مثال: علوم الحاسب'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _LabelledField(
                    label: 'اللجنة',
                    child: isHrOrAdmin
                        ? committeesAsync.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (e, _) => Text('${S.error}: $e'),
                            data: (cs) => DropdownButtonFormField<int>(
                              initialValue: _committeeId,
                              items: cs
                                  .map((c) => DropdownMenuItem(
                                      value: c.id, child: Text(c.nameAr)))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _committeeId = v ?? _committeeId),
                            ),
                          )
                        : TextFormField(
                            initialValue: widget.committeeName ?? '',
                            enabled: false,
                            decoration: const InputDecoration(
                                fillColor: AppColors.surface, filled: true),
                          ),
                  ),
                  const SizedBox(height: 14),
                  _LabelledField(
                    label: 'المنصب',
                    child: DropdownButtonFormField<String>(
                      initialValue: _role,
                      items: [
                        const DropdownMenuItem(
                            value: 'member', child: Text('عضو')),
                        const DropdownMenuItem(
                            value: 'vice_head',
                            child: Text('نائب قائد اللجنة')),
                        if (isHrOrAdmin)
                          const DropdownMenuItem(
                              value: 'head',
                              child: Text('قائد اللجنة')),
                      ],
                      onChanged: (v) => setState(() => _role = v ?? 'member'),
                    ),
                  ),
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
                              strokeWidth: 2, color: Colors.white))
                      : const Text('إنشاء العضو'),
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
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: GoogleFonts.cairo(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  onPressed: _saving ? null : () => context.pop(),
                  child: const Text(S.cancel),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              'ملاحظة: كلمة المرور الافتراضية ستكون رقم الجوال (٩ خانات).',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelledField extends StatelessWidget {
  const _LabelledField({required this.label, required this.child});
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
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600)),
        ),
        child,
      ],
    );
  }
}
