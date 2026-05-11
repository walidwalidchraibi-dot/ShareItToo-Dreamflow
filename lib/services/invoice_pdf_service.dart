import 'dart:core' as pw;
import 'dart:core';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:lendify/models/invoice.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class InvoicePdfService {
  static Future<Uint8List> buildPdf(Invoice invoice) async {
    try {
      final doc = pw.Document(
        title: 'Rechnung ${invoice.invoiceNumber}',
        author: 'ShareItToo',
        creator: 'ShareItToo App',
      );

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) {
            return [
              _header(invoice),
              pw.SizedBox(height: 16),
              _meta(invoice),
              pw.SizedBox(height: 18),
              _bookingDetails(invoice),
              pw.SizedBox(height: 18),
              _pricing(invoice),
              pw.SizedBox(height: 18),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Text('Hinweis: Diese Rechnung wird dynamisch aus deinen Buchungsdaten erstellt.', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            ];
          },
        ),
      );

      return await doc.save();
    } catch (e) {
      debugPrint('[InvoicePdfService] buildPdf failed: $e');
      rethrow;
    }
  }

  static pw.Widget _header(Invoice invoice) {
    pw.String _typeLabel() {
      switch (invoice.type) {
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

    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Expanded(
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(_typeLabel(), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text('ShareItToo', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        ]),
      ),
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Text(invoice.invoiceNumber, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(invoice.bookingId, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      ]),
    ]);
  }

  static pw.Widget _meta(Invoice invoice) {
    final d = invoice.date;
    String dt() {
      String two(int v) => v.toString().padLeft(2, '0');
      return '${two(d.day)}.${two(d.month)}.${d.year}';
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(10)),
      child: pw.Row(children: [
        pw.Expanded(child: _kv('Datum', dt())),
        pw.SizedBox(width: 12),
        pw.Expanded(child: _kv('Buchungs-ID', invoice.bookingId)),
        pw.SizedBox(width: 12),
        pw.Expanded(child: _kv('Interne ID', invoice.requestId)),
      ]),
    );
  }

  static pw.Widget _bookingDetails(Invoice invoice) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('Buchungsdetails', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      _kv('Artikel', invoice.booking.itemTitle),
      _kv('Mieter', invoice.booking.renterName),
      _kv('Vermieter', invoice.booking.ownerName),
      _kv('Mietdauer', '${invoice.booking.rentalDays} Tage'),
    ]);
  }

  static pw.Widget _pricing(Invoice invoice) {
    final p = invoice.pricing;
    String eur(double v) => '${v.toStringAsFixed(2)} €';
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('Preisübersicht', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      _rowMoney('Mietpreis', eur(p.netAmount)),
      pw.Divider(color: PdfColors.grey300),
      _rowMoney('Gesamtbetrag', eur(p.totalAfterTax), bold: true),
      pw.SizedBox(height: 8),
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(10)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('ShareItToo Plattformgebühr', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('10% des Gesamtbetrags nach Steuern', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 2),
          pw.Text('Dieser Beleg ist keine Umsatzsteuerrechnung.', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 8),
          _rowMoney('SIT Gebühr', eur(p.platformFee)),
          _rowMoney('Auszahlung an Vermieter', eur(p.payoutToOwner), bold: true),
        ]),
      ),
    ]);
  }

  static pw.Widget _kv(String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(width: 90, child: pw.Text(k, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
        pw.Expanded(child: pw.Text(v, style: const pw.TextStyle(fontSize: 10))),
      ]),
    );
  }

  static pw.Widget _rowMoney(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(children: [
        pw.Expanded(child: pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ]),
    );
  }
}
