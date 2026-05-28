class ApiEndpoints {
  static const String baseUrl = 'http://localhost:8000/api/v1';

  static const String login = '/auth/login';
  
  static String ping(int officerId) => '/dispatch/officers/$officerId/ping';
  static String pollDispatch(int officerId) => '/dispatch/officers/$officerId/dispatch';
  static String respondDispatch(int officerId, int alertId) => '/dispatch/officers/$officerId/dispatch/$alertId';
  
  static String resolveAlert(int alertId) => '/sos/alerts/$alertId/resolve';
  static String falseAlarm(int alertId) => '/sos/alerts/$alertId/false_alarm';
  
  static String triggerSos(int officerId) => '/officers/$officerId/sos';
}
