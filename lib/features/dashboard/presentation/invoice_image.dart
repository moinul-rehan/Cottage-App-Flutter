import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:cottage/models/profile.dart';
import '../data/dashboard_data.dart';
import 'package:cottage/helpers/format_month.dart';

/// Colors lifted straight from src/lib/generate-invoice-image.ts's COLORS
/// constant, so the Flutter invoice reads as the same document as the web
/// app's canvas-rendered PNG.
class _InvoiceColors {
  static const primary = Color(0xFFDE7356);
  static const primaryTint = Color(0xFFFBEAE5);
  static const foreground = Color(0xFF17191E);
  static const muted = Color(0xFF7A818D);
  static const border = Color(0xFFE4E5E8);
  static const green = Color(0xFF63B64E);
  static const greenTint = Color(0x1F63B64E);
  static const red = Color(0xFFFF4F4F);
  static const redTint = Color(0x1FFF4F4F);
}

/// A member's personal utility statement, laid out to mirror the sections
/// and order of generateInvoicePng in src/lib/generate-invoice-image.ts:
/// header -> "Prepared for" -> Summary cards -> Carried Over table ->
/// Assigned Utilities table -> Deposits table -> footer note. Rendered
/// off-screen (see InvoiceCapture) and captured to a PNG via RepaintBoundary.
class InvoiceCard extends StatelessWidget {
  final Profile profile;
  final DashboardData data;

  const InvoiceCard({super.key, required this.profile, required this.data});

  @override
  Widget build(BuildContext context) {
    final due = data.myDue.due;
    final dueLabel = due < 0 ? 'Advance Balance' : 'Remaining Due';
    final dueColor = due < 0 ? _InvoiceColors.green : _InvoiceColors.red;
    final dueTint = due < 0 ? _InvoiceColors.greenTint : _InvoiceColors.redTint;

    return Container(
      width: 720,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(monthLabel: formatMonthKey(data.monthKey)),
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 16, 48, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PreparedFor(profile: profile),
                const SizedBox(height: 16),
                const Divider(color: _InvoiceColors.border, height: 1),
                const SizedBox(height: 16),
                const _SectionTitle('Summary'),
                const SizedBox(height: 12),
                _SummaryCards(
                  assignedCost: data.myAssignedCost,
                  paid: data.myDue.paid,
                  dueLabel: dueLabel,
                  dueValue: due.abs(),
                  dueColor: dueColor,
                  dueTint: dueTint,
                ),
                const SizedBox(height: 16),
                if (data.myCarryInLines.isNotEmpty) ...[
                  const _SectionTitle('Carried Over'),
                  const SizedBox(height: 12),
                  _StripedTable(
                    headers: const ['', 'SOURCE', 'AMOUNT'],
                    rows: data.myCarryInLines
                        .map((l) => _TableRow(left: '', mid: l.label, amount: l.amount, signed: true))
                        .toList(),
                    emptyText: 'Nothing carried over.',
                    totalLabel: 'Total',
                    totalValue: _formatSigned(data.myCarryInLines.fold<double>(0, (s, l) => s + l.amount)),
                  ),
                  const SizedBox(height: 16),
                ],
                const _SectionTitle('Assigned Utilities'),
                const SizedBox(height: 12),
                _StripedTable(
                  headers: const ['DATE', 'CATEGORY', 'AMOUNT'],
                  rows: data.myAdjustmentLines
                      .map((l) => _TableRow(left: _shortDate(l.date), mid: l.label, amount: l.amount, signed: true))
                      .toList(),
                  emptyText: 'No utility costs yet this month.',
                  totalLabel: 'Total',
                  totalValue: '${data.myAssignedCost.toStringAsFixed(2)} tk',
                ),
                const SizedBox(height: 16),
                const _SectionTitle('Deposits'),
                const SizedBox(height: 12),
                _StripedTable(
                  headers: const ['DATE', 'NOTE', 'AMOUNT'],
                  rows: data.myDepositLines
                      .map((l) => _TableRow(left: _shortDate(l.date), mid: l.note ?? '-', amount: l.amount, signed: false, forceColor: _InvoiceColors.green))
                      .toList(),
                  emptyText: 'No deposits recorded this month.',
                  totalLabel: 'Total',
                  totalValue: '${data.myDue.paid.toStringAsFixed(2)} tk',
                ),
                const SizedBox(height: 16),
                const Divider(color: _InvoiceColors.border, height: 1),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'This is a system-generated statement - verify with your cottage manager if something looks incorrect.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: _InvoiceColors.muted),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Generated via Cottage · ${_shortDate(DateTime.now())}',
                    style: TextStyle(fontSize: 10, color: _InvoiceColors.muted),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String monthLabel;
  const _Header({required this.monthLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _InvoiceColors.primaryTint,
      padding: const EdgeInsets.fromLTRB(48, 24, 48, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cottage',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: _InvoiceColors.primary),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Personal Utility Statement',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _InvoiceColors.foreground),
              ),
              const SizedBox(height: 4),
              Text(
                monthLabel,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: _InvoiceColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreparedFor extends StatelessWidget {
  final Profile profile;
  const _PreparedFor({required this.profile});

  @override
  Widget build(BuildContext context) {
    final infoLines = [profile.email, profile.mobileNumber, profile.address].whereType<String>().where((s) => s.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PREPARED FOR',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _InvoiceColors.muted),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: _InvoiceColors.primaryTint,
              backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
              child: profile.avatarUrl == null
                  ? Text(
                      profile.firstName.isNotEmpty ? profile.firstName[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: _InvoiceColors.primary),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName.isNotEmpty ? profile.fullName : profile.displayName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _InvoiceColors.foreground),
                ),
                const SizedBox(height: 4),
                for (final line in infoLines)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(line, style: const TextStyle(fontSize: 13, color: _InvoiceColors.muted)),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _InvoiceColors.primary, letterSpacing: 0.4),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final double assignedCost;
  final double paid;
  final String dueLabel;
  final double dueValue;
  final Color dueColor;
  final Color dueTint;

  const _SummaryCards({
    required this.assignedCost,
    required this.paid,
    required this.dueLabel,
    required this.dueValue,
    required this.dueColor,
    required this.dueTint,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      (label: 'Assigned Cost', value: '${assignedCost.toStringAsFixed(2)} tk', tint: _InvoiceColors.primaryTint, color: _InvoiceColors.foreground),
      (label: 'Paid', value: '${paid.toStringAsFixed(2)} tk', tint: _InvoiceColors.greenTint, color: _InvoiceColors.green),
      (label: dueLabel, value: '${dueValue.toStringAsFixed(2)} tk', tint: dueTint, color: dueColor),
    ];
    return Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 76,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cards[i].tint, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(cards[i].label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _InvoiceColors.muted)),
                  const SizedBox(height: 6),
                  Text(cards[i].value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: cards[i].color)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TableRow {
  final String left;
  final String mid;
  final double amount;
  final bool signed;
  final Color? forceColor;

  const _TableRow({required this.left, required this.mid, required this.amount, required this.signed, this.forceColor});

  String get amountText => signed ? _formatSigned(amount) : '${amount.toStringAsFixed(2)} tk';

  Color get amountColor => forceColor ?? (amount >= 0 ? _InvoiceColors.red : _InvoiceColors.green);
}

/// A banded table: solid primary header bar, alternating white/tint row
/// stripes, and a solid primary total bar -- mirrors drawStripedTable in
/// generate-invoice-image.ts.
class _StripedTable extends StatelessWidget {
  final List<String> headers;
  final List<_TableRow> rows;
  final String emptyText;
  final String totalLabel;
  final String totalValue;

  const _StripedTable({
    required this.headers,
    required this.rows,
    required this.emptyText,
    required this.totalLabel,
    required this.totalValue,
  });

  @override
  Widget build(BuildContext context) {
    const rowH = 34.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Column(
        children: [
          Container(
            color: _InvoiceColors.primary,
            height: rowH,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                SizedBox(width: 80, child: Text(headers[0], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
                Expanded(child: Text(headers[1], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
                Text(headers[2], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
          if (rows.isEmpty)
            Container(
              color: Colors.white,
              height: rowH,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(emptyText, style: const TextStyle(fontSize: 13, color: _InvoiceColors.muted)),
            )
          else
            for (int i = 0; i < rows.length; i++)
              Container(
                color: i % 2 == 0 ? Colors.white : _InvoiceColors.primaryTint,
                height: rowH,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(rows[i].left, style: const TextStyle(fontSize: 12, color: _InvoiceColors.muted), overflow: TextOverflow.ellipsis),
                    ),
                    Expanded(
                      child: Text(
                        rows[i].mid,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _InvoiceColors.foreground),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(rows[i].amountText, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: rows[i].amountColor)),
                  ],
                ),
              ),
          Container(
            color: _InvoiceColors.primary,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Text(totalLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                const Spacer(),
                Text(totalValue, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatSigned(double amount) => '${amount >= 0 ? '+' : '−'}${amount.abs().toStringAsFixed(2)} tk';

String _shortDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${date.day} ${months[date.month - 1]}';
}

/// Renders [InvoiceCard] off-screen into a PNG byte buffer via
/// RepaintBoundary -- mirrors generateInvoicePng in
/// src/lib/generate-invoice-image.ts (which uses the Canvas API instead,
/// since it runs in a browser).
class InvoiceCapture {
  /// [context] just needs to resolve to a live Overlay (any widget context
  /// inside the app works, e.g. the sheet's own BuildContext) -- the invoice
  /// is inserted as a transient OverlayEntry positioned off-screen, captured,
  /// then removed.
  static Future<Uint8List> capture(BuildContext context, {required Profile profile, required DashboardData data}) async {
    final repaintKey = GlobalKey();
    final renderView = _OffscreenHost(child: RepaintBoundary(key: repaintKey, child: InvoiceCard(profile: profile, data: data)));

    final overlayState = Overlay.of(context, rootOverlay: true);
    final overlayEntry = OverlayEntry(builder: (_) => renderView);
    overlayState.insert(overlayEntry);

    try {
      // Let a frame render so the RenderRepaintBoundary has content.
      await Future.delayed(const Duration(milliseconds: 100));
      final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } finally {
      overlayEntry.remove();
    }
  }
}

/// Positions the offscreen invoice far outside the visible viewport instead
/// of using Offstage (which skips layout/paint entirely and would produce a
/// blank capture).
class _OffscreenHost extends StatelessWidget {
  final Widget child;
  const _OffscreenHost({required this.child});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: -10000,
      top: 0,
      child: Material(
        color: Colors.transparent,
        child: child,
      ),
    );
  }
}
