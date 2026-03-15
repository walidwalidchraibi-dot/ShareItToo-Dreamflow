import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:lendify/models/invoice.dart';
import 'package:lendify/services/invoice_pdf_service.dart';
import 'package:lendify/theme.dart';
import 'package:printing/printing.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final Invoice invoice;
  final bool autoStartDownload;
  const InvoiceDetailScreen({super.key, required this.invoice, this.autoStartDownload = false});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoStartDownload) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _downloadPdf());
    }
  }

  Future<void> _downloadPdf() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await InvoicePdfService.buildPdf(widget.invoice);
      await Printing.layoutPdf(
        name: '${widget.invoice.invoiceNumber}.pdf',
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      debugPrint('[InvoiceDetail] download failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF konnte nicht erstellt werden.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sharePdf() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await InvoicePdfService.buildPdf(widget.invoice);
      await Printing.sharePdf(bytes: bytes, filename: '${widget.invoice.invoiceNumber}.pdf');
    } catch (e) {
      debugPrint('[InvoiceDetail] share failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teilen fehlgeschlagen.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final inv = widget.invoice;

    final cardRadius = 18.0;
    final cardColor = Colors.black.withValues(alpha: 0.30);
    final borderColor = Colors.white.withValues(alpha: 0.07);

    return Stack(children: [
      Positioned.fill(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(color: Colors.black.withValues(alpha: 0.34)),
        ),
      ),
      Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).maybePop()),
          title: Text(_typeLabel(inv.type)),
        ),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                children: [
                  Text(_typeLabel(inv.type), style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(inv.bookingId, style: theme.textTheme.titleMedium?.copyWith(color: Colors.white.withValues(alpha: 0.88))),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(cardRadius),
                      border: Border.all(color: borderColor),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.30), blurRadius: 16, offset: const Offset(0, 10))],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _kv(context, 'Datum', _formatDate(inv.date)),
                      _kv(context, 'Buchungs-ID', inv.bookingId),
                      _kv(context, 'Rechnungsnr.', inv.invoiceNumber),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(cardRadius),
                      border: Border.all(color: borderColor),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.26), blurRadius: 16, offset: const Offset(0, 10))],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Buchungsdetails', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 10),
                      _kv(context, 'Artikel', inv.booking.itemTitle),
                      _kv(context, 'Vermieter', inv.booking.ownerName),
                      _kv(context, 'Mietdauer', '${inv.booking.rentalDays} Tage'),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(cardRadius),
                      border: Border.all(color: borderColor),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.26), blurRadius: 16, offset: const Offset(0, 10))],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Preisübersicht', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 10),
                      _moneyRow(context, 'Mietpreis', inv.pricing.netAmount),
                      _moneyRow(context, 'Mehrwertsteuer', inv.pricing.taxAmount),
                      const SizedBox(height: 8),
                      Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                      const SizedBox(height: 8),
                      _moneyRow(context, 'Gesamtbetrag (inkl. Steuer)', inv.pricing.totalAfterTax, emphasize: true),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.black.withValues(alpha: 0.20),
                          border: Border.all(color: cs.primary.withValues(alpha: 0.22)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(colors: [BrandColors.logoGradientStart, BrandColors.logoGradientEnd]),
                              ),
                              child: Icon(Icons.percent_rounded, color: Colors.white.withValues(alpha: 0.95), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text('ShareItToo Plattformgebühr', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800))),
                          ]),
                          const SizedBox(height: 8),
                          Text('10 % des Gesamtbetrags nach Steuern', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.76))),
                          const SizedBox(height: 10),
                          _moneyRow(context, 'SIT Gebühr', inv.pricing.platformFee),
                          _moneyRow(context, 'Auszahlung an Vermieter', inv.pricing.payoutToOwner, emphasize: true),
                        ]),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.30),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              ),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _downloadPdf,
                    icon: Icon(Icons.picture_as_pdf_rounded, color: _busy ? Colors.white54 : cs.primary),
                    label: Text('PDF herunterladen', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                      backgroundColor: Colors.black.withValues(alpha: 0.18),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _sharePdf,
                    icon: Icon(Icons.ios_share_rounded, color: cs.onPrimary),
                    label: Text('Beleg teilen', style: theme.textTheme.bodyMedium?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w800)),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }
}

String _typeLabel(InvoiceType type) {
  switch (type) {
    case InvoiceType.invoice:
      return 'Rechnung';
    case InvoiceType.payment:
      return 'Zahlung';
    case InvoiceType.refund:
      return 'Rückerstattung';
    case InvoiceType.fee:
      return 'Gebühr';
  }
}

Widget _kv(BuildContext context, String k, String v) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 110, child: Text(k, style: theme.textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.72)))),
      Expanded(child: Text(v, style: theme.textTheme.bodyMedium)),
    ]),
  );
}

Widget _moneyRow(BuildContext context, String label, double amount, {bool emphasize = false}) {
  final theme = Theme.of(context);
  final style = emphasize
      ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)
      : theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.90));
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Expanded(child: Text(label, style: style)),
      Text(_formatEuro(amount), style: style),
    ]),
  );
}

String _formatEuro(double v) {
  final s = v.toStringAsFixed(2).replaceAll('.', ',');
  return '$s €';
}

String _formatDate(DateTime dt) {
  const months = [
    'Januar',
    'Februar',
    'März',
    'April',
    'Mai',
    'Juni',
    'Juli',
    'August',
    'September',
    'Oktober',
    'November',
    'Dezember',
  ];
  final m = months[(dt.month - 1).clamp(0, 11)];
  return '${dt.day}. $m ${dt.year}';
}
