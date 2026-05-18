import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/localization/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/auth_repository.dart';

/// Mockup #1 — login screen.
/// Pure white background, centered logo disc, headline + "عاون" subtitle,
/// two stacked labelled fields (email + password), full-width purple
/// action, "أو" divider, and a purple text link to view tasks as guest.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _universityId = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _universityId.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithPhoneAndUniversityId(
            phone: _phone.text,
            universityId: _universityId.text,
          );
      if (mounted) context.go('/');
    } catch (_) {
      setState(() => _error = S.loginFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Logo(),
                    const SizedBox(height: 20),
                    Text(
                      'نظام إدارة مهام الفرق واللجان',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'عاون',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _LabelledField(
                      label: 'رقم الجوال',
                      child: TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textAlign: TextAlign.right,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+ ]')),
                        ],
                        decoration: const InputDecoration(
                            hintText: '05XXXXXXXX'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? S.required
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _LabelledField(
                      label: 'الرقم الجامعي',
                      child: TextFormField(
                        controller: _universityId,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                            hintText: '4XXXXXXXX'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? S.required
                            : null,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                            color: AppColors.statusOverdue, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(S.login),
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      const Expanded(child: Divider(color: AppColors.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'أو',
                          style: GoogleFonts.cairo(
                              color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ),
                      const Expanded(child: Divider(color: AppColors.border)),
                    ]),
                    const SizedBox(height: 6),
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/tasks?guest=1'),
                        child: Text(
                          'عرض المهام من النظام',
                          style: GoogleFonts.cairo(
                            color: AppColors.purple,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Two hands" logo disc — soft purple background with a stylized
/// giving-hands glyph in the brand purple.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: AppColors.purpleLight,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.purple.withValues(alpha: 0.18),
              width: 1.5),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.volunteer_activism,
          color: AppColors.purple,
          size: 56,
        ),
      ),
    );
  }
}

/// Mockup-style label-above-input.
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
          child: Text(
            label,
            style: GoogleFonts.cairo(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13),
          ),
        ),
        child,
      ],
    );
  }
}
