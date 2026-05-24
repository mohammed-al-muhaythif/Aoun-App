// Shared visual primitives that match the approved mockups.
// Every screen in the app should build from these — never re-style.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

// ─── headers ────────────────────────────────────────────────────────

/// Purple-gradient hero card used at the top of dashboards and the
/// task-detail screen. Title large white, optional trailing widget
/// (e.g. stats row, action buttons).
class GradientHero extends StatelessWidget {
  const GradientHero({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.bottom,
    this.actions,
    this.padding = const EdgeInsets.all(18),
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget? bottom;
  final List<Widget>? actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: AppColors.purpleGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subtitle != null)
                      Text(subtitle!,
                          style: GoogleFonts.cairo(
                              color: Colors.white70, fontSize: 12)),
                    Text(title,
                        style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          if (actions != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              for (var i = 0; i < actions!.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                actions![i],
              ],
            ]),
          ],
          if (bottom != null) ...[const SizedBox(height: 12), bottom!],
        ],
      ),
    );
  }
}

// ─── cards ──────────────────────────────────────────────────────────

/// Standard white surface card used everywhere. Soft shadow, 14r corners.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: card,
    );
  }
}

/// Section header — small label above a card, e.g. "إحصائيات اللجنة".
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(children: [
        Text(text,
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.textPrimary)),
        const Spacer(),
        ?trailing,
      ]),
    );
  }
}

/// Label / value row inside an info card (used by task detail).
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueWeight = FontWeight.w600,
  });
  final String label;
  final String value;
  final Color? valueColor;
  final FontWeight valueWeight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Text(label,
            style: GoogleFonts.cairo(
                color: AppColors.textSecondary, fontSize: 13)),
        const Spacer(),
        Text(value,
            style: GoogleFonts.cairo(
                fontWeight: valueWeight,
                fontSize: 13,
                color: valueColor ?? AppColors.textPrimary)),
      ]),
    );
  }
}

// ─── pills / dots ──────────────────────────────────────────────────

/// Pill badge used for statuses & priorities. Soft tint background.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: GoogleFonts.cairo(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

/// Small colored dot — used on task list rows.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.size = 10});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ─── avatars ───────────────────────────────────────────────────────

/// Avatar circle with Arabic-initial fallback. The mockups rotate
/// through purple shades; we vary by char-hash so different members
/// get distinct (but on-brand) circle colors.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({
    super.key,
    required this.name,
    this.radius = 22,
    this.fontSize = 14,
  });
  final String name;
  final double radius;
  final double fontSize;

  static const _palette = [
    AppColors.purple,
    AppColors.purpleDark,
    Color(0xFFE89AC7),  // pink-purple
    Color(0xFFF59E0B),  // amber accent (used sparingly)
    Color(0xFF8B7BE0),
  ];

  Color get _bg {
    if (name.isEmpty) return AppColors.purple;
    return _palette[name.characters.first.codeUnits.first % _palette.length];
  }

  String get _initial =>
      name.isEmpty ? '?' : name.characters.first.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final bg = _bg;
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _initial,
        style: GoogleFonts.cairo(
          color: bg,
          fontWeight: FontWeight.w800,
          fontSize: fontSize,
        ),
      ),
    );
  }
}

// ─── tabs ──────────────────────────────────────────────────────────

/// Mockup-style underline tabs: amber bar under the active tab,
/// gray text for inactive.
class UnderlineTabs extends StatelessWidget {
  const UnderlineTabs({
    super.key,
    required this.labels,
    required this.activeIndex,
    required this.onTap,
  });
  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: i == activeIndex
                            ? AppColors.statusInProgress
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      color: i == activeIndex
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight:
                          i == activeIndex ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── stat tiles ────────────────────────────────────────────────────

/// 2x2 stats grid used on the member dashboard. Big number, small label.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: GoogleFonts.cairo(
                      fontSize: 12, color: AppColors.textSecondary)),
              const Spacer(),
              if (icon != null) Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.cairo(
                  fontSize: 26, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

// ─── primary / outline buttons (action rows on top of hero) ────────

class PillButton extends StatelessWidget {
  const PillButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
  })  : _outlined = false;

  const PillButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
  })  : _outlined = true;

  final String label;
  final VoidCallback? onPressed;
  final bool _outlined;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 13,
      color: _outlined ? Colors.white : AppColors.purple,
    );
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _outlined ? Colors.transparent : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 1.2),
        ),
        child: Text(label, style: GoogleFonts.cairo().merge(base)),
      ),
    );
  }
}
