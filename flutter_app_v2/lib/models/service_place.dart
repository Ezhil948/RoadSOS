class ServicePlace {
  final String id;
  final String name;
  final String type;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String? phone;
  final String? address;
  final bool isCached;

  String get distanceLabel {
    if (distanceKm < 1.0) {
      return '${(distanceKm * 1000).round()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  ServicePlace({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    this.phone,
    this.address,
    this.isCached = false,
  });

  factory ServicePlace.fromJson(Map<String, dynamic> json) {
    return ServicePlace(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      distanceKm: (json['distance_km'] ?? 0.0).toDouble(),
      phone: json['phone'],
      address: json['address'],
      isCached: json['is_cached'] ?? false,
    );
  }
}
