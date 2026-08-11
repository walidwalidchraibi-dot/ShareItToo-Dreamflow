/// Returns a real rating that is safe to show, or `null` when no valid
/// rating exists. A zero value means the owner has not been rated yet.
double? listingRatingForDisplay(double? rating) {
  if (rating == null || !rating.isFinite || rating <= 0 || rating > 5) {
    return null;
  }
  return rating;
}

/// Normalizes the user's configured city without inventing a default.
String? configuredUserCity(String? city) {
  final normalized = city?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

/// Produces a truthful location label for a listing card.
///
/// Distance is only shown when it was calculated from a real user location.
/// Otherwise the listing city is shown, or the supplied unavailable label.
String listingLocationLabel({
  required double? distanceKm,
  required String listingCity,
  required String unavailableLabel,
}) {
  if (distanceKm != null && distanceKm.isFinite && distanceKm >= 0) {
    return '${distanceKm.toStringAsFixed(distanceKm < 10 ? 1 : 0)} km';
  }

  final city = listingCity.trim();
  return city.isNotEmpty ? city : unavailableLabel;
}
