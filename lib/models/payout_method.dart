import 'package:flutter/foundation.dart';

enum PayoutMethodType { sepa, paypal }

PayoutMethodType? payoutMethodTypeFromString(String? value) {
  if (value == null) return null;
  for (final t in PayoutMethodType.values) {
    if (t.name == value) return t;
  }
  return null;
}

@immutable
class PayoutMethod {
  final String id;
  final PayoutMethodType type;
  final bool isDefault;

  /// Display label, e.g. "Bankkonto" or "PayPal".
  final String label;

  /// Masked or last4 helper for IBAN.
  final String? last4;

  /// For SEPA.
  final String? holderName;
  final String? iban;
  final String? bic;

  /// For PayPal.
  final String? paypalEmail;

  final DateTime createdAt;
  final DateTime updatedAt;

  const PayoutMethod({
    required this.id,
    required this.type,
    required this.isDefault,
    required this.label,
    this.last4,
    this.holderName,
    this.iban,
    this.bic,
    this.paypalEmail,
    required this.createdAt,
    required this.updatedAt,
  });

  PayoutMethod copyWith({
    String? id,
    PayoutMethodType? type,
    bool? isDefault,
    String? label,
    String? last4,
    String? holderName,
    String? iban,
    String? bic,
    String? paypalEmail,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PayoutMethod(
      id: id ?? this.id,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      label: label ?? this.label,
      last4: last4 ?? this.last4,
      holderName: holderName ?? this.holderName,
      iban: iban ?? this.iban,
      bic: bic ?? this.bic,
      paypalEmail: paypalEmail ?? this.paypalEmail,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'isDefault': isDefault,
      'label': label,
      'last4': last4,
      'holderName': holderName,
      'iban': iban,
      'bic': bic,
      'paypalEmail': paypalEmail,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PayoutMethod.fromJson(Map<String, dynamic> json) {
    final type = payoutMethodTypeFromString(json['type'] as String?) ?? PayoutMethodType.sepa;
    DateTime parseDate(dynamic v) {
      if (v is String) {
        final parsed = DateTime.tryParse(v);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return PayoutMethod(
      id: (json['id'] as String?) ?? '',
      type: type,
      isDefault: (json['isDefault'] as bool?) ?? false,
      label: (json['label'] as String?) ?? (type == PayoutMethodType.paypal ? 'PayPal' : 'Bankkonto'),
      last4: json['last4'] as String?,
      holderName: json['holderName'] as String?,
      iban: json['iban'] as String?,
      bic: json['bic'] as String?,
      paypalEmail: json['paypalEmail'] as String?,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }
}
