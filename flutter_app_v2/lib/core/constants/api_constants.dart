class ApiConstants {
  static const String baseUrl = 'https://roadsos-backend-htmk.onrender.com';
  static const String nearbyServicesEndpoint = '/api/v1/services/nearby';
  static const String reportAccidentEndpoint = '/api/v1/accident/report';
  static const String sosAlertEndpoint = '/api/v1/sos/alert';
  static const String osmNominatimUrl = 'https://nominatim.openstreetmap.org';

  static String cancelSosEndpoint(int alertId) => '/api/v1/sos/alerts/$alertId/cancel';
}

