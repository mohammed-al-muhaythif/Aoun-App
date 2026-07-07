import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/localization/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/team_repository.dart';
import '../../shared/widgets/design_system.dart';

class CreateTeamScreen extends ConsumerStatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  ConsumerState<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends ConsumerState<CreateTeamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _memberQuery = TextEditingController();
  final Set<String> _memberIds = {};
  String _query = '';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _memberQuery.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(teamRepositoryProvider).createTeam(
            name: _name.text.trim(),
            description: _description.text.trim().isEmpty
                ? null
                : _description.text.trim(),
            memberIds: _memberIds.toList(),
          );
      ref.invalidate(teamsProvider);
      if (mounted) context.pop();
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
      appBar: AppBar(title: const Text('فريق جديد')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LabelledChild(
                    label: 'اسم الفريق',
                    child: TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                          hintText: 'مثال: فريق التصوير'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? S.required
                          : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _LabelledChild(
                    label: 'الغرض / الوصف (اختياري)',
                    child: TextFormField(
                      controller: _description,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'وصف مختصر لمهمة الفريق…',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SectionTitle('الأعضاء'),
            AppCard(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Column(
                children: [
                  TextField(
                    controller: _memberQuery,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search,
                          size: 20, color: AppColors.textSecondary),
                      hintText: 'ابحث عن عضو…',
                      hintStyle: GoogleFonts.cairo(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  membersAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: LinearProgressIndicator(),
                    ),
                    error: (e, _) => Text('${S.error}: $e'),
                    data: (members) {
                      final filtered = _query.isEmpty
                          ? members
                          : members
                              .where((m) => m.fullName.contains(_query))
                              .toList();
                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 320),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(
                              height: 1, color: AppColors.border),
                          itemBuilder: (_, i) {
                            final m = filtered[i];
                            final selected = _memberIds.contains(m.id);
                            return InkWell(
                              onTap: () => setState(() {
                                selected
                                    ? _memberIds.remove(m.id)
                                    : _memberIds.add(m.id);
                              }),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 4),
                                child: Row(children: [
                                  Checkbox(
                                    value: selected,
                                    activeColor: AppColors.purple,
                                    onChanged: (v) => setState(() {
                                      v == true
                                          ? _memberIds.add(m.id)
                                          : _memberIds.remove(m.id);
                                    }),
                                  ),
                                  InitialAvatar(name: m.fullName, radius: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(m.fullName,
                                            style: GoogleFonts.cairo(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700)),
                                        Text(m.primaryRoleLabel,
                                            style: GoogleFonts.cairo(
                                                fontSize: 11,
                                                color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                ]),
                              ),
                            );
                          },
                        ),
                      );
                    },
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
                      : const Text('إنشاء الفريق'),
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
