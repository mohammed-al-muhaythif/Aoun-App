import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/localization/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/committee_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../shared/widgets/design_system.dart';
import '../../shared/widgets/empty_state.dart';

/// Edit a member's profile (name / phone / uni id / major).
/// Permission is enforced server-side by `update_member_info` RPC.
class EditMemberScreen extends ConsumerStatefulWidget {
  const EditMemberScreen({super.key, required this.memberId});
  final String memberId;
  @override
  ConsumerState<EditMemberScreen> createState() => _EditMemberScreenState();
}

class _EditMemberScreenState extends ConsumerState<EditMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _uni = TextEditingController();
  final _major = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

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
      await ref.read(committeeRepositoryProvider).updateMemberInfo(
            userId: widget.memberId,
            fullName: _name.text.trim(),
            phone: _phone.text.trim(),
            universityId: _uni.text.trim(),
            major: _major.text.trim().isEmpty ? null : _major.text.trim(),
          );
      ref.invalidate(allMembersProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث المعلومات بنجاح')));
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
    final membersAsync = ref.watch(allMembersProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('تعديل معلومات العضو'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${S.error}: $e')),
        data: (members) {
          final m = members.where((x) => x.id == widget.memberId).firstOrNull;
          if (m == null) return const EmptyState(message: S.noData);
          if (!_loaded) {
            _name.text = m.fullName;
            _phone.text = m.phone ?? '';
            _uni.text = m.universityId ?? '';
            _major.text = m.major ?? '';
            _loaded = true;
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LabelledField(
                        label: 'الاسم الكامل',
                        child: TextFormField(
                          controller: _name,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? S.required : null,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _LabelledField(
                        label: 'رقم الجوال',
                        child: TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9+ ]'))
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return S.required;
                            final d = v.replaceAll(RegExp(r'\D'), '');
                            if (d.length < 9) return 'رقم غير صالح';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      _LabelledField(
                        label: 'الرقم الجامعي',
                        child: TextFormField(
                          controller: _uni,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? S.required : null,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _LabelledField(
                        label: 'التخصص الدراسي',
                        child: TextFormField(controller: _major),
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
                          : const Text('حفظ التعديلات'),
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
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'تنبيه: تعديل رقم الجوال سيُغيّر كلمة المرور تلقائيًا (كلمة المرور = الجوال).',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: AppColors.statusOverdue),
                  ),
                ),
              ],
            ),
          );
        },
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
