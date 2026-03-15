import 'package:flutter/foundation.dart';

enum SitCreditTransactionType { deposit, spend, payout }

SitCreditTransactionType? sitCreditTransactionTypeFromString(String? value) {
  if (value == null) return null;
  for (final t in SitCreditTransactionType.values) {
    if (t.name == value) return t;
  }
  return null;
}

@immutable
class SitCreditTransaction {
  final String id;
  final SitCreditTransactionType type;

  /// Positive for incoming (deposit), negative for outgoing (spend/payout).
  final double amount;
  final String title;
  final String? subtitle;
  final DateTime createdAt;

  const SitCreditTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.title,
    this.subtitle,
    required this.createdAt,
  });

  SitCreditTransaction copyWith({
    String? id,
    SitCreditTransactionType? type,
    double? amount,
    String? title,
    String? subtitle,
    DateTime? createdAt,
  }) {
    return SitCreditTransaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'title': title,
        'subtitle': subtitle,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SitCreditTransaction.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is String) {
        final parsed = DateTime.tryParse(v);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    final type = sitCreditTransactionTypeFromString(json['type'] as String?) ?? SitCreditTransactionType.deposit;
    final amountRaw = json['amount'];
    final amount = amountRaw is num ? amountRaw.toDouble() : double.tryParse(amountRaw?.toString() ?? '') ?? 0.0;
    return SitCreditTransaction(
      id: (json['id'] as String?) ?? '',
      type: type,
      amount: amount,
      title: (json['title'] as String?) ?? 'Transaktion',
      subtitle: json['subtitle'] as String?,
      createdAt: parseDate(json['createdAt']),
    );
  }
}
