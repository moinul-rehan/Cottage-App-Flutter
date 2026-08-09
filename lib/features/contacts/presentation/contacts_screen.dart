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
        builder: (sheetContext, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.call_outlined,
                    size: 20,
                    color: Color(0xFF17191E),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Create Contact',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF17191E),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(sheetContext),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Color(0xFF404040),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Text(
                    'Name ',
                    style: TextStyle(fontSize: 13, color: Color(0xFF404040)),
                  ),
                  Text(
                    '*',
                    style: TextStyle(fontSize: 13, color: Color(0xFFCC4F4F)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(fontSize: 13, color: Color(0xFF404040)),
                decoration: _contactFieldDecoration('e.g. Rafiqul Islam'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Text(
                    'Category ',
                    style: TextStyle(fontSize: 13, color: Color(0xFF404040)),
                  ),
                  Text(
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
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF404040),
                  ),
                  decoration: _contactFieldDecoration('Servant'),
                  textCapitalization: TextCapitalization.words,
                ),
              ],
              const SizedBox(height: 16),
              const Row(
                children: [
                  Text(
                    'Phone ',
                    style: TextStyle(fontSize: 13, color: Color(0xFF404040)),
                  ),
                  Text(
                    '*',
                    style: TextStyle(fontSize: 13, color: Color(0xFFCC4F4F)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: phoneCtrl,
                style: const TextStyle(fontSize: 13, color: Color(0xFF404040)),
                decoration: _contactFieldDecoration('01711-223344'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              const Text(
                'Email (optional)',
                style: TextStyle(fontSize: 13, color: Color(0xFF404040)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: emailCtrl,
                style: const TextStyle(fontSize: 13, color: Color(0xFF404040)),
                decoration: _contactFieldDecoration('name@example.com'),
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
        ),
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

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Scaffold(
      backgroundColor: CottageColors.primary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.responsivePadding,
                8,
                context.responsivePadding,
                16,
              ),
              child: Row(
                children: [
                  const Text(
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
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: surface.card,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: FutureBuilder<_ContactsData>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
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
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _refresh,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    final data = snapshot.data!;
                    return RefreshIndicator(
                      onRefresh: () async => _refresh(),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          context.responsivePadding,
                          24,
                          context.responsivePadding,
                          24 + MediaQuery.paddingOf(context).bottom,
                        ),
                        children: [
                          const Text(
                            'Necessary people for the Cottage - landlord, electrician, and the like.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF303030),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _CreateContactButton(
                            onTap: () => _showCreateContact(data.profile),
                          ),
                          const SizedBox(height: 16),
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
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Figma node 84:1123's field style: #FAFAFA fill, #EEEEEE border, 10px
/// radius, 14/12 padding, #AAAAAA hint text -- used by every text field in
/// the Create Contact drawer.
InputDecoration _contactFieldDecoration(String hint) {
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
    borderSide: BorderSide(color: Color(0xFFEEEEEE)),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
    filled: true,
    fillColor: const Color(0xFFFAFAFA),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDE7356) : const Color(0xFFFAFAFA),
          border: Border.all(
            color: selected ? const Color(0xFFDE7356) : const Color(0xFFEEEEEE),
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : const Color(0xFF404040),
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
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFEEEEEE)),
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
              const Icon(Icons.add, size: 20, color: Color(0xFF404040)),
              const SizedBox(width: 8),
              const Text(
                'Create Contact',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF404040),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEEEEEE), width: 0.8),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Color(0xFF404040),
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
                    color: const Color(0xFFFAFAFA),
                    border: Border.all(
                      color: const Color(0xFFEEEEEE),
                      width: 0.8,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: Color(0xFF404040),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        border: Border.all(color: const Color(0xFFEEEEEE), width: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF404040)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF404040)),
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
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFEEEEEE)),
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
              color: enabled
                  ? const Color(0xFF404040)
                  : const Color(0xFFBBBBBB),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: enabled
                    ? const Color(0xFF404040)
                    : const Color(0xFFBBBBBB),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
