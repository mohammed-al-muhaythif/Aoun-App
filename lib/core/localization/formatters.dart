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

/// Convert any integer to Arabic-Indic digits — e.g. 1746 → "١٧٤٦".
String toArabicDigits(num n) {
  const indic = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
  final out = StringBuffer();
  for (final ch in n.toString().split('')) {
    final i = '0123456789'.indexOf(ch);
    out.write(i >= 0 ? indic[i] : ch);
  }
  return out.toString();
}

/// Volunteer-hours display: minutes followed by "دقيقة" in Arabic digits.
/// e.g. 45 → "٤٥ دقيقة", 1746 → "١٧٤٦ دقيقة".
String formatMinutes(int m) => '${toArabicDigits(m)} دقيقة';
