import 'package:lendify/models/multi_criteria_review.dart';
import 'package:lendify/models/review.dart';

class ReviewMetricAggregate {
  final String key;
  final double average;
  final int count;

  const ReviewMetricAggregate({
    required this.key,
    required this.average,
    required this.count,
  });
}

class UserReviewSummary {
  final List<ReviewWithUser> reviews;
  final double averageRating;
  final int reviewCount;
  final List<ReviewMetricAggregate> criterionAverages;

  const UserReviewSummary({
    required this.reviews,
    required this.averageRating,
    required this.reviewCount,
    required this.criterionAverages,
  });
}

class ReviewMetricsService {
  static const String renterToOwner = 'renter_to_owner';
  static const String ownerToRenter = 'owner_to_renter';

  static const String communication = 'communication';
  static const String reliability = 'reliability';
  static const String articleAsDescribed = 'article_as_described';
  static const String handoverReturn = 'handover_return';

  static const String legacyConditionDropoff = 'condition_dropoff';
  static const String legacyConditionReturn = 'condition_return';
  static const String legacyDescriptionAccuracy = 'description_accuracy';
  static const String legacyValueForMoney = 'value_for_money';
  static const String legacyProcess = 'process';

  static const List<String> requiredKeys = [
    communication,
    reliability,
    articleAsDescribed,
    handoverReturn,
  ];

  static const List<String> criterionDisplayOrder = requiredKeys;

  static double roundToSingleDecimal(double value) =>
      (value * 10).roundToDouble() / 10.0;

  static String formatRatingValue(double value) =>
      roundToSingleDecimal(value).toStringAsFixed(1).replaceAll('.', ',');

  static bool isSupportedDirection(String direction) =>
      direction == renterToOwner || direction == ownerToRenter;

  static bool isValidCriterionValue(int stars) => stars >= 1 && stars <= 5;

  static Map<String, ReviewCriterion> _criteriaByKey(
    List<ReviewCriterion> criteria,
  ) {
    final map = <String, ReviewCriterion>{};
    for (final criterion in criteria) {
      if (criterion.key.isEmpty || map.containsKey(criterion.key)) continue;
      map[criterion.key] = criterion;
    }
    return map;
  }

  static ReviewCriterion? _firstValid(
    Map<String, ReviewCriterion> byKey,
    List<String> keys,
  ) {
    for (final key in keys) {
      final criterion = byKey[key];
      if (criterion != null && isValidCriterionValue(criterion.stars)) {
        return criterion;
      }
    }
    return null;
  }

  static List<ReviewCriterion> normalizeCriteria(
    List<ReviewCriterion> criteria, {
    String? direction,
  }) {
    final byKey = _criteriaByKey(criteria);
    final normalized = <ReviewCriterion>[];

    void addCanonical(String canonicalKey, List<String> fallbacks) {
      final source = _firstValid(byKey, [canonicalKey, ...fallbacks]);
      if (source == null) return;
      normalized.add(
        ReviewCriterion(
          key: canonicalKey,
          stars: source.stars,
          note: source.note,
        ),
      );
    }

    addCanonical(communication, const []);
    addCanonical(reliability, const []);
    addCanonical(articleAsDescribed, const [legacyDescriptionAccuracy]);
    addCanonical(
      handoverReturn,
      direction == ownerToRenter
          ? const [legacyProcess, legacyConditionReturn]
          : const [legacyProcess, legacyConditionDropoff],
    );

    return normalized;
  }

  static MultiCriteriaReview normalizeReview(MultiCriteriaReview review) {
    return MultiCriteriaReview(
      id: review.id,
      requestId: review.requestId,
      itemId: review.itemId,
      reviewerId: review.reviewerId,
      reviewedUserId: review.reviewedUserId,
      direction: review.direction,
      criteria: normalizeCriteria(review.criteria, direction: review.direction),
      createdAt: review.createdAt,
    );
  }

  static bool hasCompleteCriteria({
    required String direction,
    required List<ReviewCriterion> criteria,
  }) {
    if (!isSupportedDirection(direction)) return false;
    final normalized = normalizeCriteria(criteria, direction: direction);
    final byKey = _criteriaByKey(normalized);
    if (byKey.length != requiredKeys.length) return false;
    for (final key in requiredKeys) {
      final criterion = byKey[key];
      if (criterion == null || !isValidCriterionValue(criterion.stars)) {
        return false;
      }
    }
    return true;
  }

  static double? calculateReviewScoreFromCriteria({
    required String direction,
    required List<ReviewCriterion> criteria,
  }) {
    if (!hasCompleteCriteria(direction: direction, criteria: criteria)) {
      return null;
    }
    final byKey = _criteriaByKey(
      normalizeCriteria(criteria, direction: direction),
    );
    final total = requiredKeys
        .map((key) => byKey[key]!.stars.toDouble())
        .fold<double>(0, (sum, value) => sum + value);
    return roundToSingleDecimal(total / requiredKeys.length);
  }

  static double? calculateReviewScore(MultiCriteriaReview review) {
    return calculateReviewScoreFromCriteria(
      direction: review.direction,
      criteria: review.criteria,
    );
  }

  static bool isValidReviewContext(MultiCriteriaReview review) {
    return review.id.isNotEmpty &&
        review.requestId.isNotEmpty &&
        review.itemId.isNotEmpty &&
        review.reviewerId.isNotEmpty &&
        review.reviewedUserId.isNotEmpty &&
        review.reviewerId != review.reviewedUserId &&
        isSupportedDirection(review.direction);
  }

  static bool isRegularCompleteReview(MultiCriteriaReview review) {
    return isValidReviewContext(review) &&
        hasCompleteCriteria(
          direction: review.direction,
          criteria: review.criteria,
        ) &&
        calculateReviewScore(review) != null;
  }

  static ReviewWithUser withCalculatedReviewRating(ReviewWithUser entry) {
    final multiReview = entry.multiReview;
    final normalizedReview =
        multiReview == null ? null : normalizeReview(multiReview);
    final correctedRating = normalizedReview == null
        ? roundToSingleDecimal(entry.review.rating)
        : calculateReviewScore(normalizedReview);
    if (correctedRating == null) {
      return ReviewWithUser(
        review: entry.review,
        reviewer: entry.reviewer,
        item: entry.item,
        requestId: entry.requestId,
        multiReview: normalizedReview,
      );
    }
    return ReviewWithUser(
      review: entry.review.copyWith(rating: correctedRating),
      reviewer: entry.reviewer,
      item: entry.item,
      requestId: entry.requestId,
      multiReview: normalizedReview,
    );
  }

  static List<ReviewWithUser> normalizeReviewEntries(
      List<ReviewWithUser> reviews) {
    final byId = <String, ReviewWithUser>{};
    for (final rawEntry in reviews) {
      if (rawEntry.review.id.isEmpty) continue;
      final entry = withCalculatedReviewRating(rawEntry);
      final multiReview = entry.multiReview;
      if (multiReview == null || !isRegularCompleteReview(multiReview)) {
        continue;
      }
      final existing = byId[entry.review.id];
      if (existing == null ||
          entry.review.createdAt.isAfter(existing.review.createdAt)) {
        byId[entry.review.id] = entry;
      }
    }
    final list = byId.values.toList()
      ..sort((a, b) => b.review.createdAt.compareTo(a.review.createdAt));
    return list;
  }

  static UserReviewSummary calculateUserSummary(List<ReviewWithUser> reviews) {
    final normalized = normalizeReviewEntries(reviews);
    if (normalized.isEmpty) {
      return const UserReviewSummary(
        reviews: [],
        averageRating: 0,
        reviewCount: 0,
        criterionAverages: [],
      );
    }

    final total = normalized
        .map((entry) => entry.review.rating)
        .fold<double>(0, (sum, rating) => sum + rating);
    final sums = <String, double>{};
    final counts = <String, int>{};

    for (final entry in normalized) {
      final criteria = entry.multiReview?.criteria ?? const <ReviewCriterion>[];
      final byKey = _criteriaByKey(criteria);
      for (final key in criterionDisplayOrder) {
        final criterion = byKey[key];
        if (criterion == null || !isValidCriterionValue(criterion.stars)) {
          continue;
        }
        sums[key] = (sums[key] ?? 0) + criterion.stars;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    return UserReviewSummary(
      reviews: normalized,
      averageRating: roundToSingleDecimal(total / normalized.length),
      reviewCount: normalized.length,
      criterionAverages: [
        for (final key in criterionDisplayOrder)
          if ((counts[key] ?? 0) > 0)
            ReviewMetricAggregate(
              key: key,
              average: roundToSingleDecimal((sums[key] ?? 0) / counts[key]!),
              count: counts[key]!,
            ),
      ],
    );
  }
}
