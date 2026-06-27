import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/push/onesignal_service.dart';
import '../../core/theme/app_theme.dart';
import 'design_system.dart';

/// Self-managing "تفعيل الإشعارات" card.
///
/// • Renders nothing once permission is already granted (or while loading).
/// • On a context where push can't work yet — most importantly an iOS Safari
///   *tab* that hasn't been installed — it shows "أضِف إلى الشاشة الرئيسية"
///   guidance instead of a dead button.
/// • Otherwise shows a button that calls [OneSignalService.requestPermission]
///   from a real tap, satisfying iOS 16.4+'s user-gesture requirement.
///
/// Drop it at the top of any screen, e.g. the notifications list.
class EnablePushButton extends StatefulWidget {
  const EnablePushButton({super.key});

  @override
  State<EnablePushButton> createState() => _EnablePushButtonState();
}

class _EnablePushButtonState extends State<EnablePushButton> {
  bool _loading = true;
  bool _supported = false;
  bool _granted = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final supported = await OneSignalService.isPushSupported();
    final granted = await OneSignalService.hasPermission();
    if (!mounted) return;
    setState(() {
      _supported = supported;
      _granted = granted;
      _loading = false;
    });
  }

  Future<void> _enable() async {
    setState(() => _busy = true);
    final ok = await OneSignalService.requestPermission();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _granted = ok;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'تم تفعيل الإشعارات ✅' : 'لم يتم منح إذن الإشعارات',
          style: GoogleFonts.cairo(color: Colors.white),
        ),
        backgroundColor: ok ? AppColors.statusCompleted : AppColors.statusOverdue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _granted) return const SizedBox.shrink();

    // Push isn't available in this context yet (e.g. iOS Safari tab).
    if (!_supported) {
      return _shell(
        icon: Icons.add_to_home_screen,
        title: 'فعّل الإشعارات',
        body:
            'لتلقّي الإشعارات على الآيفون، أضِف التطبيق إلى الشاشة الرئيسية ثم افتحه من هناك.',
      );
    }

    return _shell(
      icon: Icons.notifications_active_outlined,
      title: 'فعّل الإشعارات',
      body: 'ابقَ على اطلاع بالمهام الجديدة والتحديثات لحظة بلحظة.',
      action: ElevatedButton(
        onPressed: _busy ? null : _enable,
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Text('تفعيل الإشعارات'),
      ),
    );
  }

  Widget _shell({
    required IconData icon,
    required String title,
    required String body,
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: AppColors.purple, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.cairo(
                              fontSize: 14, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(body,
                          style: GoogleFonts.cairo(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            if (action != null) ...[const SizedBox(height: 12), action],
          ],
        ),
      ),
    );
  }
}
