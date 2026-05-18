import 'package:intl/intl.dart';

/// Date formatted in Arabic with Arabic-Indic digits, e.g. "١ أبريل ٢٠٢٦".
String formatArabicDate(DateTime? d) {
  if (d == null) return '—';
  return DateFormat('d MMMM y', 'ar').format(d);
}

/// Short Arabic date, e.g. "١ أبريل".
String formatArabicDateShort(DateTime? d) {
  if (d == null) return '—';
  return DateFormat('d MMMM', 'ar').format(d);
}

/// Relative time in Arabic, e.g. "منذ ساعة".
String formatRelativeArabic(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
  if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
  if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
  return formatArabicDateShort(when);
}
