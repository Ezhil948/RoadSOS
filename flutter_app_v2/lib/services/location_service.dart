import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  bool _isTracking = false;
  bool _hasPermission = false;
  String _errorMsg = '';
  StreamSubscription<Position>? _positionStream;

  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  bool get hasPermission => _hasPermission;
  String get errorMsg => _errorMsg;

  LocationService() {
    _checkInitialPermission();
  }

  Future<void> _checkInitialPermission() async {
    // Use Geolocator directly — works on web AND mobile
    LocationPermission permission = await Geolocator.checkPermission();
    _hasPermission = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    if (_hasPermission) {
      await getCurrentLocation();
    }
    notifyListeners();
  }

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _errorMsg = 'Location services are disabled.';
      notifyListeners();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _errorMsg = 'Location permission denied.';
        _hasPermission = false;
        notifyListeners();
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _errorMsg = 'Location permissions permanently denied.';
      _hasPermission = false;
      notifyListeners();
      return false;
    }

    _hasPermission = true;
    notifyListeners();
    return true;
  }

  Future<void> getCurrentLocation() async {
    try {
      if (!_hasPermission) return;
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _errorMsg = '';
      notifyListeners();
    } catch (e) {
      _errorMsg = 'Failed to get location';
      notifyListeners();
    }
  }

  void startTracking() {
    if (!_hasPermission) return;
    _isTracking = true;
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      _currentPosition = position;
      notifyListeners();
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
    _isTracking = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}
