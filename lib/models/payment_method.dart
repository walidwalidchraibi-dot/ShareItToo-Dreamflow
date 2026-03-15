import 'package:flutter/foundation.dart';

enum PaymentMethodType {
  visa,
  mastercard,
  amex,
  applePay,
  googlePay,
  paypal,
  sepa,
}

PaymentMethodType? paymentMethodTypeFromString(String? value) {
  if (value == null) return null;
  for (final t in PaymentMethodType.values) {
    if (t.name == value) return t;
  }
  return null;
}

@immutable
class PaymentMethod {
  final String id;
  final PaymentMethodType type;
  final bool isDefault;

  /// Display label for the method, e.g. "Visa" or "PayPal" or "SEPA Bankkonto".
  final String label;

  /// Mask helper: last 4 digits for cards or IBAN.
  final String? last4;

  /// Optional for display (not sensitive).
  final String? holderName;

  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentMethod({
    required this.id,
    required this.type,
    required this.isDefault,
    required this.label,
    this.last4,
    this.holderName,
    required this.createdAt,
    required this.updatedAt,
  });

  PaymentMethod copyWith({
    String? id,
    PaymentMethodType? type,
    bool? isDefault,
    String? label,
    String? last4,
    String? holderName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentMethod(
      id: id ?? this.id,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      label: label ?? this.label,
      last4: last4 ?? this.last4,
      holderName: holderName ?? this.holderName,
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
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    final type = paymentMethodTypeFromString(json['type'] as String?) ?? PaymentMethodType.visa;
    DateTime parseDate(dynamic v) {
      if (v is String) {
        final parsed = DateTime.tryParse(v);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return PaymentMethod(
      id: (json['id'] as String?) ?? '',
      type: type,
      isDefault: (json['isDefault'] as bool?) ?? false,
      label: (json['label'] as String?) ?? type.name,
      last4: json['last4'] as String?,
      holderName: json['holderName'] as String?,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }
}
