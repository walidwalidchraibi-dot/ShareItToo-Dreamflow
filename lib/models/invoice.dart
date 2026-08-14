class Invoice {
  final String id;
  final String invoiceNumber;
  final String bookingId; // SIT-xxxxxx
  final String requestId; // internal RentalRequest id
  final InvoiceType type;
  final DateTime date;
  final String title;
  final double amount; // display amount (EUR)
  final InvoiceBookingDetails booking;
  final InvoicePriceBreakdown pricing;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.bookingId,
    required this.requestId,
    required this.type,
    required this.date,
    required this.title,
    required this.amount,
    required this.booking,
    required this.pricing,
    required this.createdAt,
    required this.updatedAt,
  });

  Invoice copyWith({
    String? id,
    String? invoiceNumber,
    String? bookingId,
    String? requestId,
    InvoiceType? type,
    DateTime? date,
    String? title,
    double? amount,
    InvoiceBookingDetails? booking,
    InvoicePriceBreakdown? pricing,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Invoice(
        id: id ?? this.id,
        invoiceNumber: invoiceNumber ?? this.invoiceNumber,
        bookingId: bookingId ?? this.bookingId,
        requestId: requestId ?? this.requestId,
        type: type ?? this.type,
        date: date ?? this.date,
        title: title ?? this.title,
        amount: amount ?? this.amount,
        booking: booking ?? this.booking,
        pricing: pricing ?? this.pricing,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'invoiceNumber': invoiceNumber,
        'bookingId': bookingId,
        'requestId': requestId,
        'type': type.name,
        'date': date.toIso8601String(),
        'title': title,
        'amount': amount,
        'booking': booking.toJson(),
        'pricing': pricing.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        id: (json['id'] ?? '').toString(),
        invoiceNumber: (json['invoiceNumber'] ?? '').toString(),
        bookingId: (json['bookingId'] ?? '').toString(),
        requestId: (json['requestId'] ?? '').toString(),
        type: InvoiceType.values.firstWhere(
          (e) => e.name == (json['type'] ?? '').toString(),
          orElse: () => InvoiceType.invoice,
        ),
        date: DateTime.tryParse((json['date'] ?? '').toString()) ??
            DateTime.now(),
        title: (json['title'] ?? '').toString(),
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        booking: InvoiceBookingDetails.fromJson(
            Map<String, dynamic>.from((json['booking'] as Map?) ?? const {})),
        pricing: InvoicePriceBreakdown.fromJson(
            Map<String, dynamic>.from((json['pricing'] as Map?) ?? const {})),
        createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
            DateTime.now(),
        updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
            DateTime.now(),
      );
}

enum InvoiceType { invoice, payment, refund, fee }

class InvoiceBookingDetails {
  final String itemTitle;
  final String renterName;
  final String ownerName;
  final int rentalDays;

  const InvoiceBookingDetails({
    required this.itemTitle,
    required this.renterName,
    required this.ownerName,
    required this.rentalDays,
  });

  InvoiceBookingDetails copyWith(
          {String? itemTitle,
          String? renterName,
          String? ownerName,
          int? rentalDays}) =>
      InvoiceBookingDetails(
        itemTitle: itemTitle ?? this.itemTitle,
        renterName: renterName ?? this.renterName,
        ownerName: ownerName ?? this.ownerName,
        rentalDays: rentalDays ?? this.rentalDays,
      );

  Map<String, dynamic> toJson() => {
        'itemTitle': itemTitle,
        'renterName': renterName,
        'ownerName': ownerName,
        'rentalDays': rentalDays,
      };

  factory InvoiceBookingDetails.fromJson(Map<String, dynamic> json) =>
      InvoiceBookingDetails(
        itemTitle: (json['itemTitle'] ?? '-').toString(),
        renterName: (json['renterName'] ?? '-').toString(),
        ownerName: (json['ownerName'] ?? '-').toString(),
        rentalDays: (json['rentalDays'] as num?)?.toInt() ?? 1,
      );
}

class InvoicePriceBreakdown {
  final double vatRate; // 0 until tax treatment is approved
  final double netAmount; // Privat-Pilot: discounted owner rental subtotal
  final double taxAmount; // 0 until tax treatment is approved
  final double totalAfterTax; // renter total including platform contribution
  final double platformFee; // exact 10% of discounted owner rental subtotal
  final double payoutToOwner;

  const InvoicePriceBreakdown({
    required this.vatRate,
    required this.netAmount,
    required this.taxAmount,
    required this.totalAfterTax,
    required this.platformFee,
    required this.payoutToOwner,
  });

  InvoicePriceBreakdown copyWith({
    double? vatRate,
    double? netAmount,
    double? taxAmount,
    double? totalAfterTax,
    double? platformFee,
    double? payoutToOwner,
  }) =>
      InvoicePriceBreakdown(
        vatRate: vatRate ?? this.vatRate,
        netAmount: netAmount ?? this.netAmount,
        taxAmount: taxAmount ?? this.taxAmount,
        totalAfterTax: totalAfterTax ?? this.totalAfterTax,
        platformFee: platformFee ?? this.platformFee,
        payoutToOwner: payoutToOwner ?? this.payoutToOwner,
      );

  Map<String, dynamic> toJson() => {
        'vatRate': vatRate,
        'netAmount': netAmount,
        'taxAmount': taxAmount,
        'totalAfterTax': totalAfterTax,
        'platformFee': platformFee,
        'payoutToOwner': payoutToOwner,
      };

  factory InvoicePriceBreakdown.fromJson(Map<String, dynamic> json) =>
      InvoicePriceBreakdown(
        vatRate: (json['vatRate'] as num?)?.toDouble() ?? 0.0,
        netAmount: (json['netAmount'] as num?)?.toDouble() ?? 0.0,
        taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0.0,
        totalAfterTax: (json['totalAfterTax'] as num?)?.toDouble() ?? 0.0,
        platformFee: (json['platformFee'] as num?)?.toDouble() ?? 0.0,
        payoutToOwner: (json['payoutToOwner'] as num?)?.toDouble() ?? 0.0,
      );
}
