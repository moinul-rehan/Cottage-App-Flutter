import 'dart:io';
import 'package:cottage/helpers/supabase_service.dart';

/// One `developer_feedback` row -- see supabase/migrations/0031_developer_feedback.sql.
class FeedbackEntry {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String memberName;
  final DateTime createdAt;

  const FeedbackEntry({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.memberName,
    required this.createdAt,
  });

  factory FeedbackEntry.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    final name = [
      profile?['first_name'],
      profile?['last_name'],
    ].where((s) => s != null && (s as String).isNotEmpty).join(' ');
    return FeedbackEntry(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      imageUrl: map['image_url'] as String?,
      memberName: name.isEmpty ? 'Member' : name,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// Data layer for "Feedback to developer" -- mirrors
/// src/app/(house)/feedback/actions.ts's submitFeedback. Any member can
/// report a bug/leave feedback (RLS: developer_feedback_insert just checks
/// user_id = auth.uid(), no can_add_* grant needed -- see migration
/// 0031_developer_feedback.sql), scoped to their own cottage. Delete is
/// self-only (developer_feedback_delete_own, migration 0049).
class FeedbackService {
  final _client = SupabaseService.client;

  Future<void> submitFeedback({
    required String cottageId,
    required String userId,
    required String title,
    required String description,
    String? imageUrl,
  }) async {
    await _client.from('developer_feedback').insert({
      'cottage_id': cottageId,
      'user_id': userId,
      'title': title,
      'description': description,
      if (imageUrl != null) 'image_url': imageUrl,
    });
  }

  /// The caller's own submissions (RLS also lets a super admin see every
  /// submission in the cottage, but "Your Feedback" per Figma is scoped to
  /// the caller regardless of role).
  Future<List<FeedbackEntry>> getMyFeedback(String userId) async {
    final rows = await _client
        .from('developer_feedback')
        .select('id, title, description, image_url, created_at, profiles!user_id(first_name, last_name)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => FeedbackEntry.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteFeedback(String id) async {
    await _client.from('developer_feedback').delete().eq('id', id);
  }

  /// Uploads to the public `feedback-attachments` bucket at
  /// `{userId}/{timestamp}.{ext}` and returns the public URL -- the owner
  /// insert policy requires the first path segment to be the caller's own
  /// auth.uid(). Every upload gets its own filename (unlike the avatar's
  /// fixed `avatar.{ext}`) since a member can attach a different screenshot
  /// to each report.
  Future<String> uploadScreenshot({
    required String userId,
    required File file,
    required String extension,
  }) async {
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage.from('feedback-attachments').upload(path, file);
    return _client.storage.from('feedback-attachments').getPublicUrl(path);
  }
}
