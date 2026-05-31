class DispatchModel {
  final int alertId;
  final double latitude;
  final double longitude;
  final String severity;
  final double distanceKm;
  final int etaMins;
  final String message;
  final List<String> reporters;
  final List<String> photos;
  final String type; // 'citizen_alert' or 'officer_backup'
  final String? officerName; // Populated if type == 'officer_backup'
  
  final bool locationUpdatePending;
  final double? newLat;
  final double? newLng;

  DispatchModel({
    required this.alertId,
    required this.latitude,
    required this.longitude,
    required this.severity,
    required this.distanceKm,
    required this.etaMins,
    required this.message,
    this.reporters = const [],
    this.photos = const [],
    this.type = 'citizen_alert',
    this.officerName,
    this.locationUpdatePending = false,
    this.newLat,
    this.newLng,
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
      reporters: (json['reporters'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      photos: (json['photos'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      type: json['type'] as String? ?? 'citizen_alert',
      officerName: json['officer_name'] as String?,
      locationUpdatePending: json['location_update_pending'] as bool? ?? false,
      newLat: json['new_lat'] != null ? (json['new_lat'] as num).toDouble() : null,
      newLng: json['new_lng'] != null ? (json['new_lng'] as num).toDouble() : null,
    );
  }

  DispatchModel copyWith({
    int? alertId,
    double? latitude,
    double? longitude,
    String? severity,
    double? distanceKm,
    int? etaMins,
    String? message,
    List<String>? reporters,
    List<String>? photos,
    String? type,
    String? officerName,
    bool? locationUpdatePending,
    double? newLat,
    double? newLng,
  }) {
    return DispatchModel(
      alertId: alertId ?? this.alertId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      severity: severity ?? this.severity,
      distanceKm: distanceKm ?? this.distanceKm,
      etaMins: etaMins ?? this.etaMins,
      message: message ?? this.message,
      reporters: reporters ?? this.reporters,
      photos: photos ?? this.photos,
      type: type ?? this.type,
      officerName: officerName ?? this.officerName,
      locationUpdatePending: locationUpdatePending ?? this.locationUpdatePending,
      newLat: newLat ?? this.newLat,
      newLng: newLng ?? this.newLng,
    );
  }
}
