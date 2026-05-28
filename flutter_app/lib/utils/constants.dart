/// Global application constants and configuration.
final class AppConstants {
  AppConstants._(); // Private constructor to prevent instantiation

  // API Base URL - change for production
  static const String baseUrl = 'http://localhost:8000'; // Host local IP for physical mobile device connection
  // static const String baseUrl = 'http://10.82.59.177:8000'; // Mobile device IP

  // API Endpoints
  static const String nearbyServicesEndpoint = '/api/v1/services/nearby';
  static const String reportAccidentEndpoint = '/api/v1/accident/report';
  static const String analyzeImageEndpoint = '/api/v1/ai/analyze';
  static const String sosAlertEndpoint = '/api/v1/sos/alert';
  static const String offlineSyncEndpoint = '/api/v1/sync/offline-data';

  // OpenStreetMap Nominatim (free, no key needed)
  static const String osmNominatimUrl = 'https://nominatim.openstreetmap.org';

  // Overpass API for OSM POI data
  static const String overpassApiUrl = 'https://overpass-api.de/api/interpreter';

  // Default search radius (meters)
  static const int defaultSearchRadius = 5000;
  static const int maxSearchRadius = 20000;

  // Service Types
  static const List<Map<String, dynamic>> serviceTypes = [
    {'key': 'police', 'label': 'Police', 'icon': '🚔', 'osm_tag': 'amenity=police', 'color': 0xFF1565C0},
    {'key': 'hospital', 'label': 'Hospital', 'icon': '🏥', 'osm_tag': 'amenity=hospital', 'color': 0xFFD32F2F},
    {'key': 'ambulance', 'label': 'Ambulance', 'icon': '🚑', 'osm_tag': 'amenity=ambulance_station', 'color': 0xFFFF6F00},
    {'key': 'towing', 'label': 'Towing', 'icon': '🚛', 'osm_tag': 'amenity=vehicle_rescue', 'color': 0xFF4527A0},
    {'key': 'puncture', 'label': 'Puncture Shop', 'icon': '🔧', 'osm_tag': 'shop=tyres', 'color': 0xFF2E7D32},
    {'key': 'showroom', 'label': 'Showroom', 'icon': '🏪', 'osm_tag': 'shop=car', 'color': 0xFF00838F},
  ];

  // Emergency Numbers by country
  static const Map<String, Map<String, String>> emergencyNumbers = {
    'IN': {'police': '100', 'ambulance': '108', 'fire': '101', 'national': '112'},
    'US': {'police': '911', 'ambulance': '911', 'fire': '911', 'national': '911'},
    'UK': {'police': '999', 'ambulance': '999', 'fire': '999', 'national': '999'},
    'DEFAULT': {'police': '112', 'ambulance': '112', 'fire': '112', 'national': '112'},
  };

  // Offline cache TTL (minutes)
  static const int cacheTtlMinutes = 60;
}
