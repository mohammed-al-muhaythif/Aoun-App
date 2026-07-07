import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/localization/formatters.dart';
import '../../core/theme/app_theme.dart';

/// Display unit for volunteer time. Storage is always in minutes;
/// `hours` is purely a presentation choice.
enum HoursUnit { minutes, hours }

/// Global preference (in-memory; resets on logout). Every screen that
/// shows volunteer time watches this and updates instantly when toggled.
final hoursUnitProvider =
    StateProvider<HoursUnit>((_) => HoursUnit.minutes);

/// Format `m` minutes per the active unit.
///
/// minutes → "٤٥ دقيقة"
/// hours   → "٠٫٧٥ ساعة"   (Arabic decimal mark)
String formatVolunteerTime(int minutes, HoursUnit unit) {
  switch (unit) {
    case HoursUnit.minutes:
      return formatMinutes(minutes);
    case HoursUnit.hours:
      final h = minutes / 60.0;
      // 2 decimals, trim trailing zeros / lonely decimal point
      var s = h.toStringAsFixed(2)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
      if (s.isEmpty || s == '-') s = '0';
      // Arabic-Indic digits + Arabic decimal separator (٫)
      final ar = toArabicDigits(num.parse(s)).replaceAll('.', '٫');
      return '$ar ساعة';
  }
}

/// Compact pill toggle: shows current unit, tap flips it.
class HoursUnitToggle extends ConsumerWidget {
  const HoursUnitToggle({super.key, this.color, this.background});

  /// Tint for text + border. Defaults to white (good on purple gradient).
  final Color? color;

  /// Background for the chip. Defaults to translucent white.
  final Color? background;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(hoursUnitProvider);
    final fg = color ?? Colors.white;
    final bg = background ?? Colors.white.withValues(alpha: 0.18);
    return InkWell(
      onTap: () {
        ref.read(hoursUnitProvider.notifier).state =
            unit == HoursUnit.minutes ? HoursUnit.hours : HoursUnit.minutes;
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: fg.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(
              unit == HoursUnit.minutes ? 'دقائق' : 'ساعات',
              style: GoogleFonts.cairo(
                  color: fg, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dark-tint variant for white backgrounds (e.g. AppBar, cards).
class HoursUnitToggleDark extends StatelessWidget {
  const HoursUnitToggleDark({super.key});
  @override
  Widget build(BuildContext context) {
    return HoursUnitToggle(
      color: AppColors.purple,
      background: AppColors.purpleLight,
    );
  }
}
