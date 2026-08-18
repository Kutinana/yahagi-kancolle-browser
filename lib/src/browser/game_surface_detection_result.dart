bool isGameSurfaceDetectionResult(Object? result) {
  if (result is bool) return result;
  if (result is String) return result.trim().toLowerCase() == 'true';
  return false;
}
