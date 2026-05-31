import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/service_place.dart';
import '../core/constants/api_constants.dart';

class ApiService extends ChangeNotifier {
  late final Dio _dio;
  late final Dio _overpassDio;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(LogInterceptor(responseBody: false));

    _overpassDio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ));
  }

  Future<List<ServicePlace>> getNearbyServices({
    required double latitude,
    required double longitude,
    required String serviceType,
    int radius = 5000,
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
      final List data = response.data['results'] ?? [];
      final places = data.map((j) => ServicePlace.fromJson(j)).toList();
      notifyListeners();
      return places;
    } on DioException {
      _isOnline = false;
      notifyListeners();
      try {
        return await _fetchFromOverpass(latitude, longitude, serviceType, radius);
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<ServicePlace>> _fetchFromOverpass(
    double lat, double lon, String type, int radius) async {
    // Default osm_tag mapping
    String osmTag = 'amenity=hospital';
    if (type == 'police') osmTag = 'amenity=police';
    if (type == 'ambulance') osmTag = 'amenity=ambulance_station';
    if (type == 'towing') osmTag = 'amenity=vehicle_rescue';
    if (type == 'puncture') osmTag = 'shop=tyres';
    if (type == 'showroom') osmTag = 'shop=car';

    final query = '''
[out:json][timeout:25];
(
  node[$osmTag](around:$radius,$lat,$lon);
  way[$osmTag](around:$radius,$lat,$lon);
);
out center 20;
''';

    final resp = await _overpassDio.post(
      ApiConstants.osmNominatimUrl.replaceFirst('nominatim', 'overpass'), // approximate fallback
      data: 'data=${Uri.encodeComponent(query)}',
      options: Options(contentType: 'application/x-www-form-urlencoded'),
    );

    final elements = resp.data['elements'] as List? ?? [];
    List<ServicePlace> places = [];

    for (var el in elements) {
      final elLat = (el['lat'] ?? el['center']?['lat'] ?? 0.0).toDouble();
      final elLon = (el['lon'] ?? el['center']?['lon'] ?? 0.0).toDouble();
      final tags = el['tags'] as Map? ?? {};
      final name = tags['name'] ?? tags['operator'] ?? 'Unknown $type';
      final phone = tags['phone'] ?? tags['contact:phone'];

      final dist = _haversineKm(lat, lon, elLat, elLon);

      places.add(ServicePlace(
        id: el['id'].toString(),
        name: name,
        type: type,
        latitude: elLat,
        longitude: elLon,
        distanceKm: dist,
        phone: phone,
        address: tags['addr:full'] ?? tags['addr:street'],
        isCached: false,
      ));
    }

    places.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return places;
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
  }) async {
    try {
      final response = await _dio.post(ApiConstants.sosAlertEndpoint, data: {
        'latitude': latitude,
        'longitude': longitude,
        'severity': severity,
        'message': message,
        'device_id': 'v2_client_device',
        'timestamp': DateTime.now().toIso8601String(),
      });
      return response.data;
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
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
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> cancelSosAlert(int alertId) async {
    try {
      final response = await _dio.post(ApiConstants.cancelSosEndpoint(alertId));
      return response.data;
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> analyzeAccidentImage(String base64Image) async {
    final response = await _dio.post(ApiConstants.analyzeImageEndpoint, data: {
      'image_base64': base64Image,
    });
    return response.data;
  }
}
