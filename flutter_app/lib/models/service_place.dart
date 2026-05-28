class ServicePlace {
  final String id;
  final String name;
  final String type;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String? phone;
  final String? address;
  final bool isOpen;
  final String? rating;
  final bool isCached;

  ServicePlace({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    this.phone,
    this.address,
    this.isOpen = true,
    this.rating,
    this.isCached = false,
  });

  factory ServicePlace.fromJson(Map<String, dynamic> json) {
    return ServicePlace(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown',
      type: json['type'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      distanceKm: (json['distance_km'] ?? 0.0).toDouble(),
      phone: json['phone'],
      address: json['address'],
      isOpen: json['is_open'] ?? true,
      rating: json['rating']?.toString(),
      isCached: json['is_cached'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'latitude': latitude,
    'longitude': longitude,
    'distance_km': distanceKm,
    'phone': phone,
    'address': address,
    'is_open': isOpen,
    'rating': rating,
    'is_cached': isCached,
  };

  String get distanceLabel {
    if (distanceKm < 1.0) return '${(distanceKm * 1000).toInt()}m';
    return '${distanceKm.toStringAsFixed(1)}km';
  }

  ServicePlace copyWith({
    String? id,
    String? name,
    String? type,
    double? latitude,
    double? longitude,
    double? distanceKm,
    String? phone,
    String? address,
    bool? isOpen,
    String? rating,
    bool? isCached,
  }) {
    return ServicePlace(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceKm: distanceKm ?? this.distanceKm,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      isOpen: isOpen ?? this.isOpen,
      rating: rating ?? this.rating,
      isCached: isCached ?? this.isCached,
    );
  }
}
