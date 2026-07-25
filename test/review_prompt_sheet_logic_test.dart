import 'package:flutter_test/flutter_test.dart';
import 'package:lendify/services/review_metrics_service.dart';
import 'package:lendify/widgets/review_prompt_sheet.dart';

void main() {
  test('formular zeigt nur vier kriteriendefinitionen', () {
    final criteria = buildReviewFormCriteria();

    expect(criteria.length, 4);
    expect(criteria.map((c) => c.key).toList(), [
      ReviewMetricsService.communication,
      ReviewMetricsService.reliability,
      ReviewMetricsService.articleAsDescribed,
      ReviewMetricsService.handoverReturn,
    ]);
  });

  test('formular-hilfetexte enthalten die neuen fachlichen erklärungen', () {
    final criteria = {for (final c in buildReviewFormCriteria()) c.key: c};

    expect(
      criteria[ReviewMetricsService.articleAsDescribed]!.helpText,
      contains('nicht, ob der Artikel neu oder hochwertig war'),
    );
    expect(
      criteria[ReviewMetricsService.handoverReturn]!.helpText,
      contains(
          'Pünktlichkeit, Sauberkeit, Funktionsfähigkeit, Zubehör und Rückgabe'),
    );
  });

  test('button-logik bleibt bei 0 bis 3 bewerteten kriterien deaktiviert', () {
    expect(areAllReviewCriteriaRated(const [0, 0, 0, 0]), isFalse);
    expect(areAllReviewCriteriaRated(const [1, 0, 0, 0]), isFalse);
    expect(areAllReviewCriteriaRated(const [1, 1, 1, 0]), isFalse);
  });

  test('button-logik wird erst bei allen 4 kriterien aktiv', () {
    expect(areAllReviewCriteriaRated(const [1, 1, 1, 1]), isTrue);
    expect(areAllReviewCriteriaRated(const [5, 4, 5, 5]), isTrue);
  });
}
