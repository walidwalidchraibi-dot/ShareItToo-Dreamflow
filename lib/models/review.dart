import 'package:lendify/models/user.dart';

/// Simple review model persisted in local storage for the demo.
class Review {
  final String id;
  final String reviewerId;
  final String reviewedUserId;
  final double rating;
  final String comment;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.reviewerId,
    required this.reviewedUserId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id'] as String,
        reviewerId: json['reviewerId'] as String,
        reviewedUserId: json['reviewedUserId'] as String,
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        comment: json['comment'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'reviewerId': reviewerId,
        'reviewedUserId': reviewedUserId,
        'rating': rating,
        'comment': comment,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Convenience view object bundling the review with the author profile.
class ReviewWithUser {
  final Review review;
  final User? reviewer;

  const ReviewWithUser({required this.review, required this.reviewer});
}
