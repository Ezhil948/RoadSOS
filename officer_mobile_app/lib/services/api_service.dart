import 'package:dio/dio.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://roadsos-backend-htmk.onrender.com',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  Future<Map<String, dynamic>?> pollDispatch(int officerId) async {
    try {
      final response = await _dio.get('/api/v1/dispatch/poll/$officerId');
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      // Ignore polling errors
    }
    return null;
  }

  Future<Map<String, dynamic>> respondToDispatch(int officerId, int alertId, String action) async {
    try {
      final response = await _dio.post('/api/v1/dispatch/respond', data: {
        'officer_id': officerId,
        'alert_id': alertId,
        'action': action,
      });
      return response.data;
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }
}
