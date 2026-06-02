import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/service_place.dart';
import '../core/constants/api_constants.dart';
import 'package:hive/hive.dart';

class ApiService extends ChangeNotifier {
  late final Dio _dio;
  late final Dio _overpassDio;
  bool _isOnline = true;
  
  bool get isOnline => _isOnline;
  
  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ));
    
    // Standardized interceptors for production
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        debugPrint('🌐 [API REQ] ${options.method} ${options.uri}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        debugPrint('✅ [API RES] ${response.statusCode} ${response.requestOptions.uri}');
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        debugPrint('❌ [API ERR] ${e.response?.statusCode} ${e.requestOptions.uri}');
        debugPrint('Error Data: ${e.response?.data}');
        return handler.next(e);
      },
    ));
    
    _overpassDio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent': 'RoadSOS-App/1.0 (contact: test@example.com)',
      },
    ));
  }
  
  // Standardized error handler
  Map<String, dynamic> _handleError(dynamic e) {
    if (e is DioException) {
      final statusCode = e.response?.statusCode;
      final message = e.response?.data?['detail'] ?? e.message;
      return {'status': 'error', 'message': message, 'code': statusCode};
    }
    return {'status': 'error', 'message': e.toString()};
  }
  
  Future<List<ServicePlace>> getNearbyServices({
    required double latitude,
    required double longitude,
    required String serviceType,
    int radius = 15000,
  }) async {
    try {
      final response = await _dio.get(
        ApiConstants.nearbyServicesEndpoint,
        queryParameters: {
          'lat': latitude,
          'lng': longitude,
          'type': serviceType,
          'radius': radius,
        },
      );
      
      _isOnline = true;
      notifyListeners();
      
      final results = response.data['results'] as List? ?? [];
      return results.map((p) => ServicePlace(
        id: p['id'].toString(),
        name: p['name'],
        type: p['type'],
        latitude: p['latitude'],
        longitude: p['longitude'],
        distanceKm: (p['distance_km'] as num).toDouble(),
        phone: p['phone'],
        address: p['address'],
        isCached: p['is_cached'] ?? false,
      )).toList();
    } catch (e) {
      _isOnline = false;
      notifyListeners();
      throw Exception('Failed to fetch nearby services: $e');
    }
  }
  
  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
  
  double _toRad(double deg) => deg * math.pi / 180;
  
  Future<Map<String, dynamic>> sendSOSAlert({
    required double latitude,
    required double longitude,
    required String severity,
    String? message,
    String? citizenName,
    String? citizenPhone,
  }) async {
    try {
      final box = await Hive.openBox('settings');
      String deviceId = box.get('device_id', defaultValue: '');
      if (deviceId.isEmpty) {
        deviceId = 'citizen_${DateTime.now().millisecondsSinceEpoch}';
        await box.put('device_id', deviceId);
      }

      final response = await _dio.post(ApiConstants.sosAlertEndpoint, data: {
        'latitude': latitude,
        'longitude': longitude,
        'severity': severity,
        'message': message,
        'device_id': deviceId,
        'timestamp': DateTime.now().toIso8601String(),
        if (citizenName != null) 'citizen_name': citizenName,
        if (citizenPhone != null) 'citizen_phone': citizenPhone,
      });
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateAlertLocation(int alertId, double lat, double lng) async {
    try {
      final box = await Hive.openBox('settings');
      String deviceId = box.get('device_id', defaultValue: '');
      final response = await _dio.post('/api/v1/sos/alerts/$alertId/location-update', data: {
        'new_lat': lat,
        'new_lng': lng,
        'device_id': deviceId,
      });
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getAlertStatus(int alertId) async {
    try {
      final response = await _dio.get('/api/v1/sos/alerts/$alertId/status');
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }
  
  Future<Map<String, dynamic>> sendAccidentReport({
    required double latitude,
    required double longitude,
    required String severity,
    required int casualties,
    String? description,
    File? image,
  }) async {
    try {
      final formData = FormData.fromMap({
        'latitude': latitude,
        'longitude': longitude,
        'severity': severity,
        'casualties': casualties,
        if (description != null && description.isNotEmpty) 'description': description,
        if (image != null)
          'image': await MultipartFile.fromFile(image.path, filename: 'accident.jpg'),
      });
      final response = await _dio.post(ApiConstants.reportAccidentEndpoint, data: formData);
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }
  
  Future<Map<String, dynamic>> cancelSosAlert(int alertId, {String? reason}) async {
    try {
      final response = await _dio.post(
        ApiConstants.cancelSosEndpoint(alertId),
        data: reason != null ? {'reason': reason} : null,
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }
  
  Future<Map<String, dynamic>> analyzeAccidentImage(String base64Image) async {
    try {
      final response = await _dio.post(ApiConstants.analyzeImageEndpoint, data: {
        'image_base64': base64Image,
      });
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }
}
