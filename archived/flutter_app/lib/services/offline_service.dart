import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/service_place.dart';
import '../utils/constants.dart';

class OfflineService extends ChangeNotifier {
  late Box _box;

  OfflineService() {
    _box = Hive.box('offline_cache');
  }

  void cacheServices(
    String type, double lat, double lng, List<ServicePlace> places) {
    final key = _buildKey(type, lat, lng);
    final data = {
      'places': places.map((p) => p.toJson()).toList(),
      'cached_at': DateTime.now().millisecondsSinceEpoch,
      'lat': lat,
      'lng': lng,
    };
    _box.put(key, jsonEncode(data));
  }

  List<ServicePlace> getCachedServices(String type, double lat, double lng) {
    final key = _buildKey(type, lat, lng);
    final raw = _box.get(key);
    if (raw == null) return [];

    final data = jsonDecode(raw);
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(data['cached_at']);
    final age = DateTime.now().difference(cachedAt).inMinutes;

    if (age > AppConstants.cacheTtlMinutes) return [];

    final List places = data['places'] ?? [];
    return places.map((j) {
      final p = ServicePlace.fromJson(j);
      return p.copyWith(isCached: true);
    }).toList();
  }

  String _buildKey(String type, double lat, double lng) {
    // Round to 2 decimal places for area-based caching (~1km grid)
    final rLat = (lat * 100).round() / 100;
    final rLng = (lng * 100).round() / 100;
    return 'services_${type}_${rLat}_$rLng';
  }

  bool hasCachedData(String type, double lat, double lng) {
    final key = _buildKey(type, lat, lng);
    final raw = _box.get(key);
    if (raw == null) return false;

    final data = jsonDecode(raw);
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(data['cached_at']);
    return DateTime.now().difference(cachedAt).inMinutes <= AppConstants.cacheTtlMinutes;
  }

  void clearCache() {
    _box.clear();
    notifyListeners();
  }
}
