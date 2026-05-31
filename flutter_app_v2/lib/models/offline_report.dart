class OfflineReport {
  final String id;
  final double latitude;
  final double longitude;
  final String severity;
  final int casualties;
  final String? description;
  final String? imagePath;
  final String timestamp;

  OfflineReport({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.severity,
    required this.casualties,
    this.description,
    this.imagePath,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'severity': severity,
        'casualties': casualties,
        'description': description,
        'imagePath': imagePath,
        'timestamp': timestamp,
      };

  factory OfflineReport.fromJson(Map<String, dynamic> json) => OfflineReport(
        id: json['id'],
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        severity: json['severity'],
        casualties: json['casualties'] as int,
        description: json['description'],
        imagePath: json['imagePath'],
        timestamp: json['timestamp'],
      );
}
