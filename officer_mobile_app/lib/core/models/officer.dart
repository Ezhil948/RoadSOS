class OfficerModel {
  final int id;
  final String name;
  final String badgeNumber;
  final String status;
  final double? latitude;
  final double? longitude;

  OfficerModel({
    required this.id,
    required this.name,
    required this.badgeNumber,
    required this.status,
    this.latitude,
    this.longitude,
  });

  factory OfficerModel.fromJson(Map<String, dynamic> json) {
    return OfficerModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Officer',
      badgeNumber: json['badge_number'] as String? ?? '',
      status: json['status'] as String? ?? 'offline',
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
    );
  }
}
