import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cottage/models/profile.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/app_toast.dart';
import 'package:cottage/common_widgets/confirm_modal.dart';
import '../data/feedback_service.dart';

/// "Feedback" -- Figma node 226:1780: a "Send Feedback" card (title,
/// description, optional screenshot attach, submit) over a "Your Feedback"
/// list of the caller's own past submissions with delete. Mirrors
/// src/app/(house)/feedback/FeedbackForm.tsx + the developer_feedback RLS
/// (any member can submit; delete is self-only, see migration 0049). Page
/// shell copies _DynamicDefaultCostHeaderDelegate's collapsing-title
/// mechanics.
class FeedbackScreen extends StatefulWidget {
  final Profile profile;
  const FeedbackScreen({super.key, required this.profile});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _feedbackService = FeedbackService();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  late Future<List<FeedbackEntry>> _future;

  File? _pickedScreenshot;
  String? _pendingScreenshotUrl;
  bool _uploadingScreenshot = false;
  bool _submitting = false;

  static const _kMaxScreenshotBytes = 1024 * 1024; // 1MB, same cap as the avatar picker.

  @override
  void initState() {
    super.initState();
    _future = _feedbackService.getMyFeedback(widget.profile.id);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {
    _future = _feedbackService.getMyFeedback(widget.profile.id);
  });

  Future<void> _pickScreenshot() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    final file = File(picked.path);
    final sizeBytes = await file.length();
    if (sizeBytes > _kMaxScreenshotBytes) {
      if (!mounted) return;
      showAppToast(
        context,
        title: 'Image too large',
        subtitle: 'Please choose a screenshot under 1MB.',
        type: ToastType.error,
      );
      return;
    }

    setState(() {
      _pickedScreenshot = file;
      _uploadingScreenshot = true;
    });
    try {
      final ext = picked.path.split('.').last;
      final url = await _feedbackService.uploadScreenshot(
        userId: widget.profile.id,
        file: file,
        extension: ext,
      );
      if (!mounted) return;
      setState(() => _pendingScreenshotUrl = url);
    } catch (_) {
      if (!mounted) return;
      showAppToast(
        context,
        title: 'Could not upload screenshot',
        subtitle: 'Please try again.',
        type: ToastType.error,
      );
      setState(() => _pickedScreenshot = null);
    } finally {
      if (mounted) setState(() => _uploadingScreenshot = false);
    }
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final description = _descCtrl.text.trim();
    if (title.isEmpty) {
      showAppToast(context, title: 'Give your feedback a title.', type: ToastType.warning);
      return;
    }
    if (description.isEmpty) {
      showAppToast(context, title: 'Describe the bug or suggestion.', type: ToastType.warning);
      return;
    }

    setState(() => _submitting = true);
    try {
      await _feedbackService.submitFeedback(
        cottageId: widget.profile.cottageId,
        userId: widget.profile.id,
        title: title,
        description: description,
        imageUrl: _pendingScreenshotUrl,
      );
      if (!mounted) return;
      showAppToast(
        context,
        title: 'Thanks for the feedback',
        subtitle: 'Your report was sent to the super admin.',
        type: ToastType.success,
      );
      _titleCtrl.clear();
      _descCtrl.clear();
      setState(() {
        _pickedScreenshot = null;
        _pendingScreenshotUrl = null;
      });
      _refresh();
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

  Future<void> _delete(FeedbackEntry entry) async {
    final confirmed = await showConfirmModal(
      context,
      icon: Icons.delete_outline,
      title: 'Delete this feedback?',
      message: 'This removes "${entry.title}" permanently.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await _feedbackService.deleteFeedback(entry.id);
      _refresh();
    } catch (_) {
      if (!mounted) return;
      showAppToast(context, title: 'Could not delete. Try again.', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;

    return Scaffold(
      backgroundColor: const Color(0xFFDE7356),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverPersistentHeader(
              pinned: true,
              delegate: _DynamicFeedbackHeaderDelegate(
                surface: surface,
                safeAreaTop: MediaQuery.of(context).padding.top,
              ),
            ),
          ];
        },
        body: Container(
          color: surface.card,
          child: FutureBuilder<List<FeedbackEntry>>(
            future: _future,
            builder: (context, snapshot) {
              final entries = snapshot.data ?? const <FeedbackEntry>[];
              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  children: [
                    _SendFeedbackCard(
                      titleCtrl: _titleCtrl,
                      descCtrl: _descCtrl,
                      pickedScreenshot: _pickedScreenshot,
                      uploadingScreenshot: _uploadingScreenshot,
                      submitting: _submitting,
                      onPickScreenshot: _pickScreenshot,
                      onSubmit: _submit,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your Feedback',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.surface.foreground,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (snapshot.connectionState != ConnectionState.done)
                      const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (entries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          "You haven't sent any feedback yet.",
                          style: TextStyle(fontSize: 13, color: surface.mutedForeground),
                        ),
                      )
                    else
                      for (final entry in entries) ...[
                        _FeedbackCard(entry: entry, onDelete: () => _delete(entry)),
                        const SizedBox(height: 10),
                      ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SendFeedbackCard extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final File? pickedScreenshot;
  final bool uploadingScreenshot;
  final bool submitting;
  final VoidCallback onPickScreenshot;
  final VoidCallback onSubmit;

  const _SendFeedbackCard({
    required this.titleCtrl,
    required this.descCtrl,
    required this.pickedScreenshot,
    required this.uploadingScreenshot,
    required this.submitting,
    required this.onPickScreenshot,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: context.surface.background,
        border: Border.all(color: context.surface.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFDE7356).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.messageSquareWarning,
                  size: 16,
                  color: Color(0xFFDE7356),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Send Feedback',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.surface.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _FeedbackField(
            label: 'Title',
            hint: "e.g. Meal count doesn't update",
            controller: titleCtrl,
          ),
          const SizedBox(height: 10),
          _FeedbackField(
            label: 'Description',
            hint: 'Describe the bug or suggestion…',
            controller: descCtrl,
            maxLines: 4,
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: uploadingScreenshot ? null : onPickScreenshot,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: context.surface.card,
                border: Border.all(color: context.surface.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    uploadingScreenshot
                        ? 'Uploading…'
                        : pickedScreenshot != null
                            ? 'Screenshot attached ✓'
                            : '+ Attach screenshot (optional)',
                    style: TextStyle(fontSize: 12, color: context.surface.mutedForeground),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: submitting ? null : onSubmit,
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFDE7356),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!submitting) ...[
                    const Icon(LucideIcons.send, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    submitting ? 'Sending…' : 'Submit Feedback',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;

  const _FeedbackField({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.surface.card,
        border: Border.all(color: context.surface.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 0),
          Text(label, style: TextStyle(fontSize: 11, color: context.surface.mutedForeground)),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: TextStyle(fontSize: 13, color: context.surface.foreground),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              border: InputBorder.none,
              hintText: hint,
              hintStyle: TextStyle(fontSize: 13, color: context.surface.mutedForeground),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final FeedbackEntry entry;
  final VoidCallback onDelete;

  const _FeedbackCard({required this.entry, required this.onDelete});

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surface.background,
        border: Border.all(color: context.surface.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: context.surface.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.surface.foreground,
                      ),
                    ),
                    Text(
                      '${entry.memberName} · ${_relativeTime(entry.createdAt)}',
                      style: TextStyle(fontSize: 11, color: context.surface.mutedForeground),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(LucideIcons.trash2, size: 15, color: CottageColors.destructive),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.description,
            style: TextStyle(fontSize: 12, color: context.surface.mutedForeground, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _DynamicFeedbackHeaderDelegate extends SliverPersistentHeaderDelegate {
  final CottageSurface surface;
  final double safeAreaTop;

  _DynamicFeedbackHeaderDelegate({required this.surface, required this.safeAreaTop});

  @override
  double get minExtent => safeAreaTop + 56.0;

  @override
  double get maxExtent => safeAreaTop + 88.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: safeAreaTop + 56 - (shrinkOffset * 1.5).clamp(0, safeAreaTop + 56),
          child: const ColoredBox(color: Color(0xFFDE7356)),
        ),
        Positioned(
          top: (safeAreaTop + 56) * (1 - progress),
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: surface.card,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20 * (1 - progress)),
                topRight: Radius.circular(20 * (1 - progress)),
              ),
            ),
          ),
        ),
        Positioned(
          top: safeAreaTop,
          left: 4,
          right: 16,
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.arrow_back,
                  color: Color.lerp(Colors.white, surface.foreground, progress),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Feedback',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color.lerp(Colors.white, surface.foreground, progress),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _DynamicFeedbackHeaderDelegate oldDelegate) => true;
}
