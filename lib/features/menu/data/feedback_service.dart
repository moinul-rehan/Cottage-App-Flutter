import 'package:cottage/helpers/supabase_service.dart';

/// Data layer for "Feedback to developer" -- mirrors
/// src/app/(house)/feedback/actions.ts's submitFeedback. Any member can
/// report a bug/leave feedback (RLS: developer_feedback_insert just checks
/// user_id = auth.uid(), no can_add_* grant needed -- see migration
/// 0031_developer_feedback.sql), scoped to their own cottage.
class FeedbackService {
  final _client = SupabaseService.client;

  Future<void> submitFeedback({
    required String cottageId,
    required String userId,
    required String title,
    required String description,
  }) async {
    await _client.from('developer_feedback').insert({
      'cottage_id': cottageId,
      'user_id': userId,
      'title': title,
      'description': description,
    });
  }
}
