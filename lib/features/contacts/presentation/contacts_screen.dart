import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cottage/models/profile.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/responsive_utils.dart';
import 'package:cottage/common_widgets/cottage_bottom_sheet.dart';
import 'package:cottage/common_widgets/empty_state.dart';
import 'package:cottage/common_widgets/confirm_modal.dart';
import 'package:cottage/helpers/ui_helpers.dart';
import '../../dashboard/data/dashboard_service.dart';
import '../data/contact.dart';
import '../data/contact_service.dart';

/// Cottage contacts screen -- landlord, electrician, and other necessary
/// people for the house. Page-shelled the same way as the Meal tab's
/// "Monthly Details" header (orange band with title, white content sheet
/// below), matching the Figma "Contacts" spec (node 27:755).
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsData {
  final Profile profile;
  final List<Contact> contacts;
  const _ContactsData({required this.profile, required this.contacts});
}

class _ContactsScreenState extends State<ContactsScreen>
    with WidgetsBindingObserver {
  final _contactService = ContactService();
  final _dashService = DashboardService();
  late Future<_ContactsData> _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A request in flight when the OS suspends the app (e.g. phone sleeps
    // overnight) has its socket killed without ever completing or erroring
    // -- the awaiting Future just hangs forever, leaving the screen stuck
    // on its loading spinner. Reloading on resume recovers from that;
    // combined with _load()'s timeout below, the screen can't get stuck
    // for longer than one foreground/background cycle.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<_ContactsData> _load() async {
    final profile = await _dashService.getCurrentProfile().timeout(
      const Duration(seconds: 15),
    );
    final contacts = await _contactService
        .getContacts(profile.cottageId)
        .timeout(const Duration(seconds: 15));
    return _ContactsData(profile: profile, contacts: contacts);
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _launch(String scheme, String value) async {
    final uri = Uri(scheme: scheme, path: value);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      showToast(context, 'Could not open $scheme link');
    }
  }

  static const _contactCategories = [
    'Landlord',
    'Electrician',
    'Plumber',
    'Other',
  ];

  /// Figma node 84:1123 ("Create Contact - Drawer"): Name/Category/Phone
  /// required, Email optional, Category is a fixed chip picker rather than
  /// free text -- still stored in the same `label` field ([Contact.label],
  /// the `level` column), which accepts any string.
  void _showCreateContact(Profile profile) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final otherCtrl = TextEditingController();
    String category = _contactCategories.first;

    showCottageSheet(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final surface = sheetContext.surface;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.call_outlined,
                      size: 20,
                      color: surface.foreground,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Create Contact',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: surface.foreground,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(sheetContext),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: surface.background,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: surface.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Name ',
                      style: TextStyle(fontSize: 13, color: surface.foreground),
                    ),
                    const Text(
                      '*',
                      style: TextStyle(fontSize: 13, color: Color(0xFFCC4F4F)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(fontSize: 13, color: surface.foreground),
                  decoration: _contactFieldDecoration(surface, 'e.g. Rafiqul Islam'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Category ',
                      style: TextStyle(fontSize: 13, color: surface.foreground),
                    ),
                    const Text(
                      '*',
                      style: TextStyle(fontSize: 13, color: Color(0xFFCC4F4F)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in _contactCategories)
                      _CategoryChip(
                        label: c,
                        selected: category == c,
                        onTap: () => setSheetState(() => category = c),
                      ),
                  ],
                ),
                if (category == 'Other') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: otherCtrl,
                    style: TextStyle(
                      fontSize: 13,
                      color: surface.foreground,
                    ),
                    decoration: _contactFieldDecoration(surface, 'Servant'),
                    textCapitalization: TextCapitalization.words,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Phone ',
                      style: TextStyle(fontSize: 13, color: surface.foreground),
                    ),
                    const Text(
                      '*',
                      style: TextStyle(fontSize: 13, color: Color(0xFFCC4F4F)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: phoneCtrl,
                  style: TextStyle(fontSize: 13, color: surface.foreground),
                  decoration: _contactFieldDecoration(surface, '01711-223344'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                Text(
                  'Email (optional)',
                  style: TextStyle(fontSize: 13, color: surface.foreground),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: emailCtrl,
                  style: TextStyle(fontSize: 13, color: surface.foreground),
                  decoration: _contactFieldDecoration(surface, 'name@example.com'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final phone = phoneCtrl.text.trim();
                    final other = otherCtrl.text.trim();
                    if (name.isEmpty || phone.isEmpty) {
                      showToast(sheetContext, 'Name and phone are required.');
                      return;
                    }
                    if (category == 'Other' && other.isEmpty) {
                      showToast(sheetContext, 'Enter a custom category.');
                      return;
                    }
                    Navigator.pop(sheetContext);
                    await _contactService.createContact(
                      cottageId: profile.cottageId,
                      createdBy: profile.id,
                      name: name,
                      label: category == 'Other' ? other : category,
                      mobileNumber: phone,
                      email: emailCtrl.text.trim().isEmpty
                          ? null
                          : emailCtrl.text.trim(),
                    );
                    _refresh();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD1593B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Save Contact',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(Contact contact) async {
    final confirmed = await showConfirmModal(
      context,
      icon: Icons.delete_outline,
      title: 'Delete contact?',
      message: "Remove ${contact.name} from contacts. This can't be undone.",
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (confirmed) {
      await _contactService.deleteContact(contact.id);
      _refresh();
    }
  }

  // Page shell mirrors UtilityStatementScreen's collapsing header (see
  // _DynamicUtilityStatementHeaderDelegate there): a NestedScrollView whose
  // orange header shrinks into a compact pinned bar as the contact list
  // scrolls, instead of a static fixed-height header band above an
  // independently scrolling body.
  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return FutureBuilder<_ContactsData>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: CottageColors.primary,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: CottageColors.primary,
            body: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: surface.card,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 40,
                      color: CottageColors.destructive,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load contacts.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: surface.foreground),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final data = snapshot.data!;

        final pageContent = Scaffold(
          backgroundColor: CottageColors.primary,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _DynamicContactsHeaderDelegate(
                    surface: surface,
                    safeAreaTop: MediaQuery.of(context).padding.top,
                    onCreateContact: () => _showCreateContact(data.profile),
                  ),
                ),
              ];
            },
            body: Container(
              color: surface.card,
              child: RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    context.responsivePadding,
                    20,
                    context.responsivePadding,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    if (data.contacts.isEmpty)
                      const EmptyState(
                        icon: Icons.contact_phone_outlined,
                        title: 'No contacts yet.',
                      )
                    else
                      for (final c in data.contacts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _ContactCard(
                            contact: c,
                            onDelete: () => _confirmDelete(c),
                            onCall: c.mobileNumber == null
                                ? null
                                : () => _launch('tel', c.mobileNumber!),
                            onEmail: c.email == null
                                ? null
                                : () => _launch('mailto', c.email!),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
        );

        if (snapshot.connectionState != ConnectionState.done) {
          return Stack(
            children: [
              pageContent,
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.15),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
          );
        }
        return pageContent;
      },
    );
  }
}

/// Collapsing header for the Contacts page -- a port of
/// _DynamicUtilityStatementHeaderDelegate's shrink-on-scroll behavior in
/// utility_statement_screen.dart, swapping its Download/Add Adjustment
/// button row for a single Create Contact button and dropping the month
/// badge (Contacts has no month concept).
class _DynamicContactsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final CottageSurface surface;
  final double safeAreaTop;
  final VoidCallback onCreateContact;

  _DynamicContactsHeaderDelegate({
    required this.surface,
    required this.safeAreaTop,
    required this.onCreateContact,
  });

  @override
  double get minExtent => safeAreaTop + 90.0;

  @override
  double get maxExtent => safeAreaTop + 174.0;

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
        // Background: Orange top, White bottom -- the orange band retreats
        // 1.5x faster than plain scroll progress so it's fully gone well
        // before the header reaches minExtent, same as Utility Statement.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height:
              safeAreaTop +
              56 -
              (shrinkOffset * 1.5).clamp(0, safeAreaTop + 56),
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

        // Expanded Content (Fades out) -- clipped in an OverflowBox because
        // the box this sits in keeps shrinking continuously as the header
        // collapses, so partway through the scroll it's already smaller than
        // this Column's fixed content height. Opacity alone doesn't stop
        // that from overflowing, so without this the mid-scroll frames show
        // a RenderFlex overflow banner.
        if (progress < 1.0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: Opacity(
              opacity: 1.0 - progress,
              child: IgnorePointer(
                ignoring: progress > 0.5,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Orange Header Content -- no back arrow, matches
                        // Figma and this app's other pushed pages, which
                        // rely on the system back gesture/button instead of
                        // an in-header one.
                        Container(
                          height: safeAreaTop + 56,
                          padding: EdgeInsets.only(
                            top: safeAreaTop,
                            left: context.responsivePadding,
                            right: context.responsivePadding,
                          ),
                          child: const Row(
                            children: [
                              Text(
                                'Contacts',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // White Card Content (Details)
                        Padding(
                          padding: EdgeInsets.only(
                            left: context.responsivePadding,
                            right: context.responsivePadding,
                            top: 16,
                          ),
                          child: Text(
                            'Necessary people for the Cottage - landlord, electrician, and the like.',
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: 14,
                              color: surface.foreground,
                            ),
                            maxLines: 2,
                          ),
                        ),
                        // Guarantees the description doesn't touch the
                        // separately-positioned button row below it (that
                        // row is pinned to the header's own bottom edge, not
                        // this Column's flow, so it needs its own explicit
                        // gap here rather than relying on leftover space).
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Collapsed Content (Fades in)
        if (progress > 0.0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: Opacity(
              opacity: progress,
              child: IgnorePointer(
                ignoring: progress < 0.5,
                child: Container(
                  padding: EdgeInsets.only(
                    top: safeAreaTop + 8,
                    left: context.responsivePadding,
                    right: context.responsivePadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contacts',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: surface.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Common bottom element (Create Contact) -- always visible
        // regardless of scroll position, same as Utility Statement's
        // Download/Add Adjustment row.
        Positioned(
          left: context.responsivePadding,
          right: context.responsivePadding,
          bottom: 8,
          child: _CreateContactButton(onTap: onCreateContact),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _DynamicContactsHeaderDelegate oldDelegate) {
    return true;
  }
}

/// Figma node 84:1123's field style: card-adjacent fill, themed border, 10px
/// radius, 14/12 padding, muted hint text -- used by every text field in the
/// Create Contact drawer.
InputDecoration _contactFieldDecoration(CottageSurface surface, String hint) {
  final border = OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(10)),
    borderSide: BorderSide(color: surface.border),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: 13, color: surface.mutedForeground),
    filled: true,
    fillColor: surface.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: border,
    enabledBorder: border,
    focusedBorder: border,
    isDense: true,
  );
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDE7356) : surface.background,
          border: Border.all(
            color: selected ? const Color(0xFFDE7356) : surface.border,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : surface.foreground,
          ),
        ),
      ),
    );
  }
}

class _CreateContactButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateContactButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: surface.card,
            border: Border.all(color: surface.border),
            borderRadius: BorderRadius.circular(1000),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 20, color: surface.foreground),
              const SizedBox(width: 8),
              Text(
                'Create Contact',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: surface.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final Contact contact;
  final VoidCallback onDelete;
  final VoidCallback? onCall;
  final VoidCallback? onEmail;

  const _ContactCard({
    required this.contact,
    required this.onDelete,
    this.onCall,
    this.onEmail,
  });

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface.card,
        border: Border.all(color: surface.border, width: 0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        contact.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: surface.foreground,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (contact.label != null && contact.label!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: CottageColors.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          contact.label!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 10.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: surface.background,
                    border: Border.all(
                      color: surface.border,
                      width: 0.8,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: surface.foreground,
                  ),
                ),
              ),
            ],
          ),
          if (contact.mobileNumber != null) ...[
            const SizedBox(height: 10),
            _InfoRow(icon: Icons.call_outlined, text: contact.mobileNumber!),
          ],
          if (contact.email != null) ...[
            const SizedBox(height: 10),
            _InfoRow(icon: Icons.mail_outline, text: contact.email!),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.call_outlined,
                  label: 'Call',
                  onTap: onCall,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.mail_outline,
                  label: 'Email',
                  onTap: onEmail,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: surface.background,
        border: Border.all(color: surface.border, width: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: surface.foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: surface.foreground),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ActionButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: surface.card,
          border: Border.all(color: surface.border),
          borderRadius: BorderRadius.circular(1000),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: enabled ? surface.foreground : surface.mutedForeground,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: enabled ? surface.foreground : surface.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
