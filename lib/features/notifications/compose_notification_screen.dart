import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/strings.dart';
import '../../core/supabase/supabase_client.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/committee_repository.dart';
import '../../data/repositories/profile_repository.dart';

enum _Target { all, committee, members }

class ComposeNotificationScreen extends ConsumerStatefulWidget {
  const ComposeNotificationScreen({super.key});

  @override
  ConsumerState<ComposeNotificationScreen> createState() =>
      _ComposeNotificationScreenState();
}

class _ComposeNotificationScreenState
    extends ConsumerState<ComposeNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  _Target _target = _Target.all;
  int? _committeeId;
  final Set<String> _userIds = {};
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<List<String>> _resolveRecipients() async {
    if (_target == _Target.members) return _userIds.toList();
    if (_target == _Target.committee && _committeeId != null) {
      final rows = await sb
          .from('committee_memberships')
          .select('user_id')
          .eq('committee_id', _committeeId!);
      return (rows as List).map((r) => r['user_id'] as String).toList();
    }
    final rows = await sb.from('profiles').select('id');
    return (rows as List).map((r) => r['id'] as String).toList();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final recipients = await _resolveRecipients();
      if (recipients.isEmpty) {
        throw Exception('لا يوجد مستلمون');
      }
      final res = await sb.functions.invoke(
        'send-push',
        body: {
          'user_ids': recipients,
          'title': _title.text.trim(),
          'body': _body.text.trim(),
        },
      );
      if (res.data is Map && res.data['ok'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('أُرسل إلى ${recipients.length} شخص')),
          );
          context.pop();
        }
      } else {
        throw Exception(res.data?.toString() ?? 'فشل الإرسال');
      }
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
    final committeesAsync = ref.watch(committeesProvider);
    final membersAsync = ref.watch(allMembersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('إرسال إشعار')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'العنوان'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? S.required : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _body,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'النص',
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? S.required : null,
            ),
            const SizedBox(height: 16),
            const Text('الهدف',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            RadioGroup<_Target>(
              groupValue: _target,
              onChanged: (v) => setState(() => _target = v!),
              child: Column(
                children: [
                  const RadioListTile<_Target>(
                    value: _Target.all,
                    activeColor: AppColors.purple,
                    title: Text('جميع الأعضاء'),
                  ),
                  const RadioListTile<_Target>(
                    value: _Target.committee,
                    activeColor: AppColors.purple,
                    title: Text('لجنة محددة'),
                  ),
                  if (_target == _Target.committee)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: committeesAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('${S.error}: $e'),
                        data: (cs) => DropdownButtonFormField<int>(
                          initialValue: _committeeId,
                          items: cs
                              .map((c) => DropdownMenuItem(
                                  value: c.id, child: Text(c.nameAr)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _committeeId = v),
                          decoration:
                              const InputDecoration(labelText: 'اللجنة'),
                        ),
                      ),
                    ),
                  const RadioListTile<_Target>(
                    value: _Target.members,
                    activeColor: AppColors.purple,
                    title: Text('أعضاء محددون'),
                  ),
                ],
              ),
            ),
            if (_target == _Target.members)
              membersAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('${S.error}: $e'),
                data: (members) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: members.map((m) {
                      return CheckboxListTile(
                        value: _userIds.contains(m.id),
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: AppColors.purple,
                        title: Text(m.fullName),
                        onChanged: (v) => setState(() {
                          v == true
                              ? _userIds.add(m.id)
                              : _userIds.remove(m.id);
                        }),
                      );
                    }).toList(),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: const Text('إرسال'),
            ),
          ],
        ),
      ),
    );
  }
}
