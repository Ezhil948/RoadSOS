class DispatchRequest {
  final int alertId;
  final double latitude;
  final double longitude;
  final String severity;
  final double distanceKm;
  final int etaMins;
  final String message;

  DispatchRequest({
    required this.alertId,
    required this.latitude,
    required this.longitude,
    required this.severity,
    required this.distanceKm,
    required this.etaMins,
    required this.message,
  });
}
