import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  bool _isLoading = false;
  String? _error;

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _error = 'Location services are disabled.';
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _error = 'Location permission denied.';
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _error = 'Location permissions permanently denied.';
      return false;
    }
    return true;
  }

  Future<Position?> getCurrentLocation() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      bool hasPermission = await requestPermission();
      if (!hasPermission) {
        _isLoading = false;
        notifyListeners();
        return null;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _isLoading = false;
      notifyListeners();
      return _currentPosition;
    } catch (e) {
      // Fallback to last known position for offline
      _currentPosition = await Geolocator.getLastKnownPosition();
      _error = 'Using last known location';
      _isLoading = false;
      notifyListeners();
      return _currentPosition;
    }
  }

  double calculateDistance(double lat2, double lon2) {
    if (_currentPosition == null) return 0;
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      lat2,
      lon2,
    ) / 1000; // in km
  }
}
