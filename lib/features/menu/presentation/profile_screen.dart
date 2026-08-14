import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cottage/models/profile.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/app_toast.dart';
import 'package:cottage/common_widgets/responsive_utils.dart';
import '../data/profile_service.dart';

/// "Profile" -- Figma nodes 211:2391 (view mode) and 211:2551 (edit mode),
/// merged into one screen: tapping "Edit Profile" doesn't push a separate
/// route, it flips [_isEditing] and each field row cross-fades in place
/// from its read-only look into an editable one (see [_ProfileField]),
/// mirroring the two Figma frames as two states of the same layout rather
/// than two destinations. Page shell copies _DynamicMealHeaderDelegate's
/// shrink-on-scroll mechanics (see meal_screen.dart), just without a tab
/// bar or bottom-pinned action row -- this page has neither.
class ProfileScreen extends StatefulWidget {
  final Profile profile;
  const ProfileScreen({super.key, required this.profile});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = ProfileService();

  late Profile _profile = widget.profile;
  bool _isEditing = false;
  bool _saving = false;
  bool _uploadingAvatar = false;
  File? _pickedAvatar;
  // Set once a picked photo finishes uploading to storage, but not
  // committed to the profile row until _submit() runs -- see
  // ProfileService.updateOwnProfile's doc comment for why this used to be
  // committed immediately on pick instead.
  String? _pendingAvatarUrl;

  late final _firstNameController = TextEditingController(
    text: _profile.firstName,
  );
  late final _lastNameController = TextEditingController(
    text: _profile.lastName ?? '',
  );
  late final _mobileController = TextEditingController(
    text: _profile.mobileNumber ?? '',
  );
  late final _hometownController = TextEditingController(
    text: _profile.hometown ?? '',
  );
  late final _addressController = TextEditingController(
    text: _profile.address ?? '',
  );
  late String? _gender = _profile.gender;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
    _hometownController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String _genderLabel(String? gender) {
    switch (gender) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      case 'other':
        return 'Other';
      default:
        return '-';
    }
  }

  void _startEditing() {
    // Re-seed every controller from the current saved profile so an edit
    // started right after a previous save (or a cancel) never shows stale
    // text from a discarded attempt.
    _firstNameController.text = _profile.firstName;
    _lastNameController.text = _profile.lastName ?? '';
    _mobileController.text = _profile.mobileNumber ?? '';
    _hometownController.text = _profile.hometown ?? '';
    _addressController.text = _profile.address ?? '';
    setState(() {
      _gender = _profile.gender;
      _isEditing = true;
    });
  }

  void _cancelEditing() => setState(() {
    _isEditing = false;
    // Discard any picked-but-unsaved photo -- the whole point of deferring
    // the commit to _submit() is that backing out here must leave the
    // saved profile (picture included) exactly as it was.
    _pickedAvatar = null;
    _pendingAvatarUrl = null;
  });

  static const _kMaxAvatarBytes = 1024 * 1024; // 1MB, same cap as web's feedback attachment

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    final file = File(picked.path);
    // Checked after picking (imageQuality:85 only recompresses JPEGs, so a
    // large PNG or an already-huge photo can still land here well over the
    // limit) rather than relying on compression alone to keep it small.
    final sizeBytes = await file.length();
    if (sizeBytes > _kMaxAvatarBytes) {
      if (!mounted) return;
      showAppToast(
        context,
        title: 'Image too large',
        subtitle: 'Please choose a photo under 1MB.',
        type: ToastType.error,
      );
      return;
    }

    setState(() {
      _pickedAvatar = file;
      _uploadingAvatar = true;
    });
    try {
      final ext = picked.path.split('.').last;
      final url = await _profileService.uploadAvatar(
        userId: _profile.id,
        file: file,
        extension: ext,
      );
      if (!mounted) return;
      // Not committed to the profile row yet -- just held here for _submit()
      // to send along with the rest of the form. The avatar preview above
      // already reads from _pickedAvatar (the local file), so this doesn't
      // need to touch _profile at all to show up on screen.
      setState(() => _pendingAvatarUrl = url);
    } catch (_) {
      if (!mounted) return;
      showAppToast(
        context,
        title: 'Could not upload image',
        subtitle: 'Please try again.',
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await _profileService.updateOwnProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim().isEmpty
            ? null
            : _lastNameController.text.trim(),
        // null (not just omitted) when no new photo was picked --
        // update_own_profile does `coalesce(p_avatar_url, avatar_url)`, so
        // null correctly means "leave the existing picture alone" rather
        // than clearing it.
        avatarUrl: _pendingAvatarUrl,
        gender: _gender,
        hometown: _hometownController.text.trim().isEmpty
            ? null
            : _hometownController.text.trim(),
        mobileNumber: _mobileController.text.trim().isEmpty
            ? null
            : _mobileController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _profile = Profile(
          id: _profile.id,
          cottageId: _profile.cottageId,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim().isEmpty
              ? null
              : _lastNameController.text.trim(),
          email: _profile.email,
          avatarUrl: _pendingAvatarUrl ?? _profile.avatarUrl,
          mobileNumber: _mobileController.text.trim().isEmpty
              ? null
              : _mobileController.text.trim(),
          address: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          roomLabel: _profile.roomLabel,
          hometown: _hometownController.text.trim().isEmpty
              ? null
              : _hometownController.text.trim(),
          gender: _gender,
          role: _profile.role,
          isActive: _profile.isActive,
          removedAt: _profile.removedAt,
          canAddExpenses: _profile.canAddExpenses,
          canAddBazaar: _profile.canAddBazaar,
          canAddMeals: _profile.canAddMeals,
          canAddDeposit: _profile.canAddDeposit,
          canAddNotice: _profile.canAddNotice,
        );
        _isEditing = false;
        _pickedAvatar = null;
        _pendingAvatarUrl = null;
      });
      showAppToast(context, title: 'Profile updated', type: ToastType.success);
    } catch (_) {
      if (!mounted) return;
      showAppToast(
        context,
        title: 'Could not save your profile',
        subtitle: 'Please try again.',
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return PopScope(
      canPop: !_isEditing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _cancelEditing();
      },
      child: Scaffold(
        backgroundColor: CottageColors.primary,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverPersistentHeader(
                pinned: true,
                delegate: _DynamicProfileHeaderDelegate(
                  surface: surface,
                  safeAreaTop: MediaQuery.of(context).padding.top,
                  onBack: _isEditing ? _cancelEditing : () => Navigator.pop(context),
                ),
              ),
            ];
          },
          body: Container(
            color: surface.card,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                context.responsivePadding,
                24,
                context.responsivePadding,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 44,
                                backgroundColor: surface.accent,
                                backgroundImage: _pickedAvatar != null
                                    ? FileImage(_pickedAvatar!)
                                    : (_profile.avatarUrl?.isNotEmpty ?? false)
                                    ? NetworkImage(_profile.avatarUrl!)
                                          as ImageProvider
                                    : null,
                                child:
                                    _pickedAvatar == null &&
                                        !(_profile.avatarUrl?.isNotEmpty ??
                                            false)
                                    ? Text(
                                        _profile.firstName.isNotEmpty
                                            ? _profile.firstName[0]
                                                  .toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w700,
                                          color: surface.accentForeground,
                                        ),
                                      )
                                    : null,
                              ),
                              // Camera badge -- only exists in edit mode
                              // (Figma: view mode's Avatar has no badge at
                              // all), scaled/faded in rather than just
                              // appearing so toggling Edit reads as one
                              // continuous transition instead of a jump cut.
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: AnimatedScale(
                                  scale: _isEditing ? 1 : 0,
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutBack,
                                  child: AnimatedOpacity(
                                    opacity: _isEditing ? 1 : 0,
                                    duration: const Duration(
                                      milliseconds: 160,
                                    ),
                                    child: GestureDetector(
                                      onTap: _uploadingAvatar
                                          ? null
                                          : _pickAvatar,
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: CottageColors.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: surface.card,
                                            width: 2,
                                          ),
                                        ),
                                        child: _uploadingAvatar
                                            ? const SizedBox(
                                                width: 12,
                                                height: 12,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 1.6,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.camera_alt,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _profile.fullName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: surface.foreground,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // "Edit Profile" pill -- fades/shrinks away once
                          // editing starts, since its job is done (the
                          // fields themselves become the interaction).
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeInOut,
                            child: AnimatedOpacity(
                              opacity: _isEditing ? 0 : 1,
                              duration: const Duration(milliseconds: 160),
                              child: _isEditing
                                  ? const SizedBox(width: double.infinity)
                                  : OutlinedButton.icon(
                                      onPressed: _startEditing,
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        size: 14,
                                        color: surface.foreground,
                                      ),
                                      label: Text(
                                        'Edit Profile',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: surface.foreground,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: surface.border,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            1000,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                    _ProfileField(
                      label: 'First name',
                      editLabel: 'First Name',
                      isEditing: _isEditing,
                      viewValue: _profile.firstName,
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          hintText: 'First name',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'First name is required.'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ProfileField(
                      label: 'Last name',
                      isEditing: _isEditing,
                      viewValue: (_profile.lastName?.isNotEmpty ?? false)
                          ? _profile.lastName!
                          : '-',
                      child: TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          hintText: 'Last name',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ProfileField(
                      label: 'Email',
                      isEditing: _isEditing,
                      viewValue: _profile.email ?? '-',
                      child: TextFormField(
                        initialValue: _profile.email ?? '',
                        enabled: false,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ProfileField(
                      label: 'Gender',
                      isEditing: _isEditing,
                      viewValue: _genderLabel(_profile.gender),
                      child: DropdownButtonFormField<String>(
                        initialValue: _gender,
                        hint: const Text('Select…'),
                        items: const [
                          DropdownMenuItem(
                            value: 'male',
                            child: Text('Male'),
                          ),
                          DropdownMenuItem(
                            value: 'female',
                            child: Text('Female'),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Text('Other'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _gender = v),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ProfileField(
                      label: 'Mobile number (BD)',
                      isEditing: _isEditing,
                      viewValue: (_profile.mobileNumber?.isNotEmpty ?? false)
                          ? _profile.mobileNumber!
                          : '-',
                      child: TextFormField(
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          hintText: '01712345678',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          return ProfileService.isValidBdMobile(v.trim())
                              ? null
                              : 'Enter a valid Bangladeshi mobile number (e.g. 01712345678).';
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ProfileField(
                      label: 'Hometown',
                      editLabel: 'Home town',
                      isEditing: _isEditing,
                      viewValue: (_profile.hometown?.isNotEmpty ?? false)
                          ? _profile.hometown!
                          : '-',
                      child: TextFormField(
                        controller: _hometownController,
                        decoration: const InputDecoration(
                          hintText: 'Home town',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ProfileField(
                      label: 'Address',
                      isEditing: _isEditing,
                      viewValue: (_profile.address?.isNotEmpty ?? false)
                          ? _profile.address!
                          : '-',
                      child: TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(hintText: 'Optional'),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      child: _isEditing
                          ? Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: ElevatedButton(
                                onPressed: _saving ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD1593B),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(1000),
                                  ),
                                ),
                                child: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Update Information',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One label+value row, animated between the two Figma frames' treatments
/// of the same field: view mode packs label (11px, muted) + value (14px,
/// medium) into one bordered chip; edit mode splits them -- a plain label
/// above, then the chip becomes an actual input. [AnimatedCrossFade] handles
/// the swap so it reads as a continuous morph instead of a layout jump.
class _ProfileField extends StatelessWidget {
  final String label;
  final String? editLabel;
  final bool isEditing;
  final String viewValue;
  final Widget child;

  const _ProfileField({
    required this.label,
    this.editLabel,
    required this.isEditing,
    required this.viewValue,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topLeft,
          child: AnimatedOpacity(
            opacity: isEditing ? 1 : 0,
            duration: const Duration(milliseconds: 160),
            child: isEditing
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      editLabel ?? label,
                      style: TextStyle(
                        fontSize: 13,
                        color: surface.mutedForeground,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: isEditing
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: surface.background,
              border: Border.all(color: surface.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: surface.mutedForeground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  viewValue,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: surface.foreground,
                  ),
                ),
              ],
            ),
          ),
          secondChild: Theme(
            // Figma-exact input chrome (bg/border/radius/padding) instead
            // of the app's default Material outline style -- this is what
            // was missing before: the edit fields used stock TextFormField
            // presets rather than matching the design.
            data: Theme.of(context).copyWith(
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: surface.background,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: surface.mutedForeground,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: surface.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: surface.border),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: surface.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: CottageColors.primary,
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: CottageColors.destructive,
                  ),
                ),
              ),
            ),
            child: DefaultTextStyle(
              style: TextStyle(fontSize: 13, color: surface.foreground),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

class _DynamicProfileHeaderDelegate extends SliverPersistentHeaderDelegate {
  final CottageSurface surface;
  final double safeAreaTop;
  final VoidCallback onBack;

  _DynamicProfileHeaderDelegate({
    required this.surface,
    required this.safeAreaTop,
    required this.onBack,
  });

  @override
  double get minExtent => safeAreaTop + 56.0;

  @override
  double get maxExtent => safeAreaTop + 88.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height:
              safeAreaTop + 56 - (shrinkOffset * 1.5).clamp(0, safeAreaTop + 56),
          child: Container(color: CottageColors.primary),
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
                onPressed: onBack,
                icon: Icon(
                  Icons.arrow_back,
                  color: Color.lerp(
                    Colors.white,
                    surface.foreground,
                    progress,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Profile',
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
  bool shouldRebuild(covariant _DynamicProfileHeaderDelegate oldDelegate) {
    return true;
  }
}
