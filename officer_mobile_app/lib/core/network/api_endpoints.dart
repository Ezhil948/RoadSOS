class ApiEndpoints {
  static const String baseUrl = 'https://roadsos-backend-htmk.onrender.com/api/v1';

  static const String login = '/auth/login';
  
  static String ping(int officerId) => '/dispatch/officers/$officerId/ping';
  static String pollDispatch(int officerId) => '/dispatch/officers/$officerId/dispatch';
  static String respondDispatch(int officerId, int alertId) => '/dispatch/officers/$officerId/dispatch/$alertId';
  
  // Finding #3: WebSocket URL now accepts a JWT token as query parameter
  static String wsDispatch(int officerId, {String token = ''}) {
    final uri = Uri.parse(baseUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final portSuffix = (uri.port != 80 && uri.port != 443 && uri.port != 0) ? ':${uri.port}' : '';
    final base = '$wsScheme://${uri.host}$portSuffix${uri.path}/dispatch/ws/officer/$officerId';
    if (token.isNotEmpty) {
      return '$base?token=$token';
    }
    return base;
  }
  
  static String resolveAlert(int alertId) => '/sos/alerts/$alertId/resolve';
  static String falseAlarm(int alertId) => '/sos/alerts/$alertId/false_alarm';
  static String cancelByPolice(int alertId) => '/sos/alerts/$alertId/police-cancel';
  static String getAlertStatus(int alertId) => '/sos/alerts/$alertId/status';
  
  static String triggerSos(int officerId) => '/officers/$officerId/sos';
  static String requestBackup(int officerId) => '/dispatch/officers/$officerId/backup';
}
