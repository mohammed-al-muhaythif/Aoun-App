import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_client.dart';
import '../models/committee.dart';

final committeesProvider = FutureProvider<List<Committee>>((ref) async {
  final rows = await sb.from('committees').select().order('id');
  return (rows as List)
      .map((m) => Committee.fromMap(m as Map<String, dynamic>))
      .toList();
});
