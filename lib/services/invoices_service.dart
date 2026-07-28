import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:lendify/models/invoice.dart';
import 'package:lendify/models/item.dart';
import 'package:lendify/models/rental_request.dart';
import 'package:lendify/models/user.dart';
import 'package:lendify/services/data_service.dart';

/// Generates invoice/receipt documents dynamically from real booking data.
///
/// IMPORTANT: The UI may show example values, but this service must never
/// reuse a single fixed invoice. Documents are generated from persisted
/// [RentalRequest]s.
class InvoicesService {
  static const double vatRateDefault = 0.19;
  static const double platformFeeRate = 0.10; // 10% AFTER taxes

  static Future<List<Invoice>> getInvoicesForCurrentUser() async {
    try {
      final current = await DataService.getCurrentUser();
      if (current == null) return const [];
      return getInvoicesForUser(current.id);
    } catch (e) {
      debugPrint('[InvoicesService] getInvoicesForCurrentUser failed: $e');
      return const [];
    }
  }

  static Future<List<Invoice>> getInvoicesForUser(String userId) async {
    try {
      final asRenter = await DataService.getRentalRequestsForRenter(userId);
      final asOwner = await DataService.getRentalRequestsForOwner(userId);

      final invoices = <Invoice>[];
      for (final r in asRenter) {
        final docs = await _documentsForRequest(r, perspectiveUserId: userId);
        invoices.addAll(docs);
      }
      for (final r in asOwner) {
        final docs = await _documentsForRequest(r, perspectiveUserId: userId);
        invoices.addAll(docs);
      }

      // Ensure unique + stable order (newest first)
      final byId = <String, Invoice>{};
      for (final inv in invoices) {
        byId[inv.id] = inv;
      }
      final out = byId.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return out;
    } catch (e) {
      debugPrint('[InvoicesService] getInvoicesForUser failed: $e');
      return const [];
    }
  }

  static Future<Invoice?> findInvoiceForCurrentUser(String invoiceId) async {
    try {
      final list = await getInvoicesForCurrentUser();
      for (final inv in list) {
        if (inv.id == invoiceId) return inv;
      }
      return null;
    } catch (e) {
      debugPrint('[InvoicesService] findInvoiceForCurrentUser failed: $e');
      return null;
    }
  }

  static Future<List<Invoice>> _documentsForRequest(
    RentalRequest req, {
    required String perspectiveUserId,
  }) async {
    final item = await DataService.getItemById(req.itemId);
    final renter = await DataService.getUserById(req.renterId);
    final owner = await DataService.getUserById(req.ownerId);
    if (item == null || renter == null || owner == null) return const [];

    // Choose a booking date: prefer completion, else createdAt.
    final date = _bookingDateFor(req);
    final bookingId = _bookingIdFor(req);

    final breakdown = _pricingForRequest(item: item, req: req);

    final bookingDetails = InvoiceBookingDetails(
      itemTitle: item.title,
      renterName: renter.displayName,
      ownerName: owner.displayName,
      rentalDays: _rentalDays(req),
    );

    final docs = <Invoice>[];
    final isHeldForReview = req.needsReview;
    if (isHeldForReview) {
      return docs;
    }

    // Renter docs
    if (perspectiveUserId == renter.id) {
      docs.add(
        _buildInvoice(
          baseId: 'inv_${req.id}',
          type: InvoiceType.invoice,
          bookingId: bookingId,
          requestId: req.id,
          date: date,
          title: '${item.title} – Buchung',
          amount: breakdown.totalAfterTax,
          booking: bookingDetails,
          pricing: breakdown,
        ),
      );

      if (_isRefund(req)) {
        final refundAmount = _refundAmount(
          totalAfterTax: breakdown.totalAfterTax,
          req: req,
        );
        docs.add(
          _buildInvoice(
            baseId: 'refund_${req.id}',
            type: InvoiceType.refund,
            bookingId: bookingId,
            requestId: req.id,
            date: date,
            title: '${item.title} – Rückerstattung',
            amount: refundAmount,
            booking: bookingDetails,
            pricing: breakdown,
          ),
        );
      }
    }

    // Owner docs
    if (perspectiveUserId == owner.id && !isHeldForReview) {
      docs.add(
        _buildInvoice(
          baseId: 'payout_${req.id}',
          type: InvoiceType.payment,
          bookingId: bookingId,
          requestId: req.id,
          date: date,
          title: '${item.title} – Auszahlung',
          amount: breakdown.payoutToOwner,
          booking: bookingDetails,
          pricing: breakdown,
        ),
      );
      docs.add(
        _buildInvoice(
          baseId: 'fee_${req.id}',
          type: InvoiceType.fee,
          bookingId: bookingId,
          requestId: req.id,
          date: date,
          title: '${item.title} – Plattformgebühr',
          amount: breakdown.platformFee,
          booking: bookingDetails,
          pricing: breakdown,
        ),
      );
    }

    return docs;
  }

  static bool _isRefund(RentalRequest req) {
    final s = req.status.toLowerCase();
    return s == 'cancelled' || s == 'declined';
  }

  static double _refundAmount({
    required double totalAfterTax,
    required RentalRequest req,
  }) {
    // Demo policy: mirror the app's unified policy when renter cancels;
    // owner cancellation is treated as 100% refund.
    try {
      if ((req.cancelledBy ?? '') == 'owner') {
        return _round2(totalAfterTax);
      }
      final ratio = DataService.refundRatio(
        policy: 'unified',
        start: req.start,
        cancelAt: DateTime.now(),
      );
      return _round2(totalAfterTax * ratio);
    } catch (_) {
      return 0.0;
    }
  }

  static DateTime _bookingDateFor(RentalRequest req) {
    // We want dates to feel meaningful:
    // - completed/running => end date (receipt issued after rental)
    // - otherwise => createdAt
    final s = req.status.toLowerCase();
    if (s == 'completed' || s == 'running') return req.end;
    return req.createdAt;
  }

  static int _rentalDays(RentalRequest req) {
    final days = (req.end.difference(req.start).inHours / 24).ceil().clamp(
      1,
      365,
    );
    return days;
  }

  static String _bookingIdFor(RentalRequest req) {
    // Stable, human-friendly booking number based on the request id.
    // We keep it deterministic so the same booking always maps to the same number.
    final seed = req.id.hashCode.abs();
    final n = 100000 + (seed % 900000);
    return 'SIT-$n';
  }

  static InvoicePriceBreakdown _pricingForRequest({
    required Item item,
    required RentalRequest req,
  }) {
    // Determine total AFTER taxes (this is what the renter effectively paid).
    // Prefer a persisted quote to stay stable across UI changes.
    final fallbackTotal = () {
      try {
        final b = DataService.priceBreakdownForRequest(item: item, req: req);
        return b.totalRenter;
      } catch (_) {
        return item.pricePerDay; // last resort
      }
    };

    final totalAfterTax = _round2(req.quotedTotalRenter ?? fallbackTotal());
    final vatRate = vatRateDefault;

    // If the amount already includes VAT, extract the tax part.
    final taxAmount = _round2(totalAfterTax * (vatRate / (1 + vatRate)));
    final netAmount = _round2(totalAfterTax - taxAmount);

    // IMPORTANT RULE: platform fee must be 10% of total AFTER taxes.
    final platformFee = _round2(totalAfterTax * platformFeeRate);
    final payout = _round2(totalAfterTax - platformFee);

    return InvoicePriceBreakdown(
      vatRate: vatRate,
      netAmount: netAmount,
      taxAmount: taxAmount,
      totalAfterTax: totalAfterTax,
      platformFee: platformFee,
      payoutToOwner: payout,
    );
  }

  static Invoice _buildInvoice({
    required String baseId,
    required InvoiceType type,
    required String bookingId,
    required String requestId,
    required DateTime date,
    required String title,
    required double amount,
    required InvoiceBookingDetails booking,
    required InvoicePriceBreakdown pricing,
  }) {
    // Avoid a single static invoice: IDs and invoice numbers are derived from
    // booking + type + time buckets for uniqueness.
    final now = DateTime.now();
    final id = '${baseId}_${type.name}';
    final invoiceNumber = _invoiceNumberFor(id: id, date: date);
    return Invoice(
      id: id,
      invoiceNumber: invoiceNumber,
      bookingId: bookingId,
      requestId: requestId,
      type: type,
      date: date,
      title: title,
      amount: _round2(amount),
      booking: booking,
      pricing: pricing,
      createdAt: now,
      updatedAt: now,
    );
  }

  static String _invoiceNumberFor({
    required String id,
    required DateTime date,
  }) {
    // e.g. SIT-INV-2026-03-483920
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final suffix = 100000 + (id.hashCode.abs() % 900000);
    return 'SIT-INV-$y-$m-$suffix';
  }

  static double _round2(double v) {
    if (v.isNaN || v.isInfinite) return 0.0;
    return double.parse(v.toStringAsFixed(2));
  }

  /// Utility: totals for a given year.
  static double sumAmountForYear(List<Invoice> invoices, int year) {
    double total = 0.0;
    for (final i in invoices) {
      if (i.date.year == year) total += i.amount;
    }
    return _round2(total);
  }

  static List<int> availableYears(List<Invoice> invoices) {
    final years = <int>{};
    for (final i in invoices) {
      years.add(i.date.year);
    }
    final out = years.toList()..sort((a, b) => b.compareTo(a));
    return out;
  }

  static List<Invoice> filter({
    required List<Invoice> invoices,
    required InvoiceFilter filter,
    int? year,
  }) {
    Iterable<Invoice> it = invoices;
    if (year != null) it = it.where((e) => e.date.year == year);

    switch (filter) {
      case InvoiceFilter.all:
        break;
      case InvoiceFilter.bookings:
        it = it.where((e) => e.type == InvoiceType.invoice);
        break;
      case InvoiceFilter.rentals:
        it = it.where((e) => e.type == InvoiceType.payment);
        break;
      case InvoiceFilter.refunds:
        it = it.where((e) => e.type == InvoiceType.refund);
        break;
      case InvoiceFilter.fees:
        it = it.where((e) => e.type == InvoiceType.fee);
        break;
    }
    final out = it.toList()..sort((a, b) => b.date.compareTo(a.date));
    return out;
  }
}

enum InvoiceFilter { all, bookings, rentals, refunds, fees }
