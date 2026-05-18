import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/localization/formatters.dart';
import '../../core/localization/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/hours_repository.dart';
import '../../shared/widgets/design_system.dart';

class LogHoursScreen extends ConsumerStatefulWidget {
  const LogHoursScreen({super.key});

  @override
  ConsumerState<LogHoursScreen> createState() => _LogHoursScreenState();
}

class _LogHoursScreenState extends ConsumerState<LogHoursScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _hours = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _description.dispose();
    _hours.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(hoursRepositoryProvider).logHours(
            description: _description.text.trim(),
            hours: double.parse(_hours.text),
            activityDate: _date,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      ref.invalidate(myHoursProvider);
      ref.invalidate(myHoursSummaryProvider);
      // Leaderboards are separately cached — refresh so newly-logged
      // hours appear right away for HR / committee-head viewers.
      ref.invalidate(leaderboardProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${S.error}: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('تسجيل ساعات تطوعية')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                      child: _LabelledChild(
                        label: 'عدد الساعات',
                        child: TextFormField(
                          controller: _hours,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}')),
                          ],
                          decoration: const InputDecoration(hintText: '2.5'),
                          validator: (v) {
                            if (v == null || v.isEmpty) return S.required;
                            final n = double.tryParse(v);
                            if (n == null || n <= 0 || n > 24) {
                              return 'بين 0 و 24';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LabelledChild(
                        label: 'تاريخ النشاط',
                        child: _DateField(date: _date, onTap: _pickDate),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _LabelledChild(
                    label: 'وصف النشاط',
                    child: TextFormField(
                      controller: _description,
                      decoration: const InputDecoration(
                          hintText: 'ما الذي قمت به؟'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? S.required
                          : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _LabelledChild(
                    label: 'ملاحظات (اختياري)',
                    child: TextFormField(
                      controller: _notes,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          hintText: 'أي تفاصيل إضافية…',
                          alignLabelWithHint: true),
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
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('حفظ الساعات'),
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
          child: Text(
            label,
            style: GoogleFonts.cairo(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600),
          ),
        ),
        child,
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap});
  final DateTime date;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: const InputDecoration(
          suffixIcon: Icon(Icons.calendar_today_outlined,
              size: 18, color: AppColors.textSecondary),
        ),
        child: Text(formatArabicDate(date),
            style: GoogleFonts.cairo(fontSize: 13)),
      ),
    );
  }
}
