class AccidentReport {
  final String id;
  final double latitude;
  final double longitude;
  final String severity; // minor, moderate, critical
  final int casualties;
  final String description;
  final List<String> imagePaths;
  final DateTime timestamp;
  final String? aiAnalysis;

  AccidentReport({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.severity,
    required this.casualties,
    required this.description,
    required this.imagePaths,
    required this.timestamp,
    this.aiAnalysis,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'latitude': latitude,
    'longitude': longitude,
    'severity': severity,
    'casualties': casualties,
    'description': description,
    'image_paths': imagePaths,
    'timestamp': timestamp.toIso8601String(),
    'ai_analysis': aiAnalysis,
  };

  factory AccidentReport.fromJson(Map<String, dynamic> json) {
    return AccidentReport(
      id: json['id']?.toString() ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      severity: json['severity'] ?? 'minor',
      casualties: json['casualties'] ?? 0,
      description: json['description'] ?? '',
      imagePaths: (json['image_paths'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
      aiAnalysis: json['ai_analysis'],
    );
  }
}
