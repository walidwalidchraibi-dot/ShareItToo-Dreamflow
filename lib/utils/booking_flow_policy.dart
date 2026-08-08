bool canStartHandover({
  required String requestStatus,
  required bool viewerIsOwner,
  required bool handoverTimeConfirmed,
  required bool handoverActive,
  required bool needsReview,
}) {
  return requestStatus.trim().toLowerCase() == 'accepted' &&
      viewerIsOwner &&
      handoverTimeConfirmed &&
      !handoverActive &&
      !needsReview;
}

bool canStartReturn({
  required String requestStatus,
  required bool viewerIsOwner,
  required bool returnTimeConfirmed,
  required bool returnActive,
}) {
  return requestStatus.trim().toLowerCase() == 'running' &&
      !viewerIsOwner &&
      returnTimeConfirmed &&
      !returnActive;
}
