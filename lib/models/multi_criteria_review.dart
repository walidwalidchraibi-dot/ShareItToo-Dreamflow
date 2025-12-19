class ReviewCriterion {
  final String key; // stable key, e.g., 'communication'
  final int stars; // 1..5
  final String? note; // optional free text per criterion

  const ReviewCriterion({required this.key, required this.stars, this.note});

  factory ReviewCriterion.fromJson(Map<String, dynamic> json) => ReviewCriterion(
        key: (json['key'] as String?) ?? '',
        stars: ((json['stars'] as num?)?.toInt() ?? 0).clamp(0, 5),
        note: json['note'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'stars': stars,
        'note': note,
      };
}

/// A multi-criteria immutable review bound to a reservation (request).
class MultiCriteriaReview {
  final String id;
  final String requestId; // reservation id
  final String itemId; // which listing this review is about (for landlord aggregation per listing)
  final String reviewerId;
  final String reviewedUserId;
  final String direction; // 'renter_to_owner' | 'owner_to_renter'
  final List<ReviewCriterion> criteria;
  final DateTime createdAt;

  const MultiCriteriaReview({
    required this.id,
    required this.requestId,
    required this.itemId,
    required this.reviewerId,
    required this.reviewedUserId,
    required this.direction,
    required this.criteria,
    required this.createdAt,
  });

  double get average => criteria.isEmpty ? 0.0 : criteria.map((e) => e.stars.toDouble()).reduce((a, b) => a + b) / criteria.length;

  factory MultiCriteriaReview.fromJson(Map<String, dynamic> json) => MultiCriteriaReview(
        id: (json['id'] as String?) ?? '',
        requestId: (json['requestId'] as String?) ?? '',
        itemId: (json['itemId'] as String?) ?? '',
        reviewerId: (json['reviewerId'] as String?) ?? '',
        reviewedUserId: (json['reviewedUserId'] as String?) ?? '',
        direction: (json['direction'] as String?) ?? 'renter_to_owner',
        criteria: [
          for (final c in (json['criteria'] as List? ?? const []))
            ReviewCriterion.fromJson(Map<String, dynamic>.from(c as Map))
        ],
        createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'requestId': requestId,
        'itemId': itemId,
        'reviewerId': reviewerId,
        'reviewedUserId': reviewedUserId,
        'direction': direction,
        'criteria': criteria.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };
}
