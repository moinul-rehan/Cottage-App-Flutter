import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cottage/models/profile.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/helpers/ui_helpers.dart';
import '../data/dashboard_data.dart';
import 'invoice_image.dart';

/// Mirrors UtilityBreakdownDialog.tsx: a bottom sheet (the mobile Sheet
/// pattern the web app also falls back to on small screens) showing the
/// current user's carry-in lines, this month's utility adjustment lines,
/// and the Assigned Cost / Paid / Remaining Due-or-Advance-Balance summary,
/// plus Save PNG / Share Invoice actions (see ShareInvoiceButton.tsx).
Future<void> showUtilityBreakdownSheet(BuildContext context, {required Profile profile, required DashboardData data}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _UtilityBreakdownSheet(profile: profile, data: data),
  );
}

class _UtilityBreakdownSheet extends StatefulWidget {
  final Profile profile;
  final DashboardData data;

  const _UtilityBreakdownSheet({required this.profile, required this.data});

  @override
  State<_UtilityBreakdownSheet> createState() => _UtilityBreakdownSheetState();
}

class _UtilityBreakdownSheetState extends State<_UtilityBreakdownSheet> {
  String? _pending; // 'save' | 'share' | null
  String? _error;

  String _fileName() {
    final month = widget.data.monthKey.replaceAll('-', '_');
    return 'utility-statement-$month.png';
  }

  Future<void> _handleSave() async {
    setState(() {
      _pending = 'save';
      _error = null;
    });
    try {
      final bytes = await InvoiceCapture.capture(context, profile: widget.profile, data: widget.data);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${_fileName()}');
      await file.writeAsBytes(bytes);
      if (mounted) {
        showToast(context, 'Saved to ${file.path}');
      }
    } catch (_) {
      setState(() => _error = 'Could not save the invoice. Try again.');
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  Future<void> _handleShare() async {
    setState(() {
      _pending = 'share';
      _error = null;
    });
    try {
      final bytes = await InvoiceCapture.capture(context, profile: widget.profile, data: widget.data);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${_fileName()}');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Utility Statement',
        text: 'Personal Utility Statement',
      );
    } catch (_) {
      setState(() => _error = 'Could not share the invoice. Try again.');
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final data = widget.data;
    final due = data.myDue.due;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: surface.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.bolt, size: 18, color: surface.foreground),
                  const SizedBox(width: 8),
                  Text(
                    'My Utility Breakdown',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: surface.foreground),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (data.myCarryInLines.isNotEmpty) ...[
                Column(
                  children: [
                    for (final line in data.myCarryInLines)
                      _LineRow(label: line.label, amount: line.amount, surface: surface),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(color: surface.border),
                const SizedBox(height: 8),
              ],
              if (data.myAdjustmentLines.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('No utility costs yet this month.', style: TextStyle(color: surface.mutedForeground, fontSize: 13)),
                )
              else
                Column(
                  children: [
                    for (final line in data.myAdjustmentLines)
                      _LineRow(label: line.label, amount: line.amount, surface: surface),
                  ],
                ),
              const SizedBox(height: 8),
              Divider(color: surface.border),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Assigned Cost', style: TextStyle(fontWeight: FontWeight.w600, color: surface.foreground)),
                  Text('${data.myAssignedCost.toStringAsFixed(2)} tk', style: TextStyle(fontWeight: FontWeight.w600, color: surface.foreground)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Paid', style: TextStyle(color: surface.mutedForeground)),
                  Text('${data.myDue.paid.toStringAsFixed(2)} tk', style: TextStyle(color: surface.mutedForeground)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    due < 0 ? 'Advance Balance' : 'Remaining Due',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: due < 0 ? const Color(0xFF059669) : CottageColors.destructive,
                    ),
                  ),
                  Text(
                    '${due.abs().toStringAsFixed(2)} tk',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: due < 0 ? const Color(0xFF059669) : CottageColors.destructive,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: surface.border),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pending == null ? _handleSave : null,
                    icon: const Icon(Icons.download, size: 16),
                    label: Text(_pending == 'save' ? 'Saving…' : 'Save PNG'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _pending == null ? _handleShare : null,
                    icon: const Icon(Icons.share, size: 16),
                    label: Text(_pending == 'share' ? 'Preparing…' : 'Share Invoice'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(_error!, style: const TextStyle(fontSize: 12, color: CottageColors.destructive)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  final String label;
  final double amount;
  final CottageSurface surface;

  const _LineRow({required this.label, required this.amount, required this.surface});

  @override
  Widget build(BuildContext context) {
    final positive = amount >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: surface.mutedForeground, fontSize: 13)),
          ),
          Text(
            '${positive ? '+' : '−'}${amount.abs().toStringAsFixed(2)} tk',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: positive ? CottageColors.destructive : const Color(0xFF059669),
            ),
          ),
        ],
      ),
    );
  }
}
