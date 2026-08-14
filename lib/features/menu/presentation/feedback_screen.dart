import 'package:flutter/material.dart';
import 'package:cottage/models/profile.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/app_toast.dart';
import '../data/feedback_service.dart';

/// "Feedback to developer" -- mirrors src/app/(house)/feedback/FeedbackForm.tsx
/// (text fields only; the web version's optional screenshot attachment
/// isn't ported here). Open to every member regardless of role/permissions,
/// matching MobileMenuSheet.tsx's always-present "Feedback" entry -- RLS's
/// developer_feedback_insert policy only checks user_id = auth.uid(), no
/// can_add_* grant required.
class FeedbackScreen extends StatefulWidget {
  final Profile profile;
  const FeedbackScreen({super.key, required this.profile});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _feedbackService = FeedbackService();
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await _feedbackService.submitFeedback(
        cottageId: widget.profile.cottageId,
        userId: widget.profile.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
      );
      if (!mounted) return;
      showAppToast(
        context,
        title: 'Thanks for the feedback',
        subtitle: 'Your report was sent to the super admin.',
        type: ToastType.success,
      );
      _titleController.clear();
      _descriptionController.clear();
      _formKey.currentState!.reset();
    } catch (_) {
      if (!mounted) return;
      showAppToast(
        context,
        title: 'Could not send feedback',
        subtitle: 'Please try again.',
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Scaffold(
      backgroundColor: surface.background,
      appBar: AppBar(
        backgroundColor: surface.background,
        foregroundColor: surface.foreground,
        elevation: 0,
        title: const Text('Feedback'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report a bug or leave feedback',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: surface.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "What happened? What did you expect instead? This goes straight to your Cottage's super admin.",
                  style: TextStyle(fontSize: 13, color: surface.mutedForeground),
                ),
                const SizedBox(height: 20),
                Text(
                  'Title',
                  style: TextStyle(fontSize: 13, color: surface.mutedForeground),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    hintText: 'Short summary of the issue',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Give your feedback a title.'
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  'Description',
                  style: TextStyle(fontSize: 13, color: surface.mutedForeground),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Describe the bug or feedback in detail',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Describe the bug or feedback.'
                      : null,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Send feedback'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
