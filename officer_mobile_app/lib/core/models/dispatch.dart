class DispatchModel {
  final int alertId;
  final double latitude;
  final double longitude;
  final String severity;
  final double distanceKm;
  final int etaMins;
  final String message;

  DispatchModel({
    required this.alertId,
    required this.latitude,
    required this.longitude,
    required this.severity,
    required this.distanceKm,
    required this.etaMins,
    required this.message,
  });

  factory DispatchModel.fromJson(Map<String, dynamic> json) {
    return DispatchModel(
      alertId: json['alert_id'] as int,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      severity: json['severity'] as String? ?? 'high',
      distanceKm: (json['distance_km'] as num).toDouble(),
      etaMins: json['eta_mins'] as int,
      message: json['message'] as String? ?? 'Emergency Dispatch',
    );
  }
}
