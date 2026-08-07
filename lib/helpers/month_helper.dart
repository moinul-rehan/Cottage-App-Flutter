import 'package:supabase_flutter/supabase_flutter.dart';

/// When the cottage's current active month began -- the `closed_at` of the
/// most recently closed prior month, or null if no month has ever been
/// closed yet. Mirrors getActiveMonthStartedAt in src/lib/data/months.ts.
/// Used to scope things like notifications to "since the current month
/// started".
Future<String?> getActiveMonthStartedAt(SupabaseClient client, String cottageId) async {
  final rows = await client
      .from('month_closures')
      .select('closed_at')
      .eq('cottage_id', cottageId)
      .order('closed_at', ascending: false)
      .limit(1);
  final list = rows as List;
  if (list.isEmpty) return null;
  return (list.first as Map<String, dynamic>)['closed_at'] as String?;
}
