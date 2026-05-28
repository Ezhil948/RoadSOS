import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/models/dispatch.dart';
import '../../app.dart';
import 'package:hive_flutter/hive_flutter.dart';

sealed class OfficerStatus {}
class Offline extends OfficerStatus {}
class Online extends OfficerStatus {}      // scanning, no dispatch
class Dispatching extends OfficerStatus {  // overlay shown
  final DispatchModel dispatch;
  Dispatching(this.dispatch);
}
class Navigating extends OfficerStatus {   // map visible
  final DispatchModel dispatch;
  Navigating(this.dispatch);
}
class Arrived extends OfficerStatus {      // resolve/false alarm
  final DispatchModel dispatch;
  Arrived(this.dispatch);
}

class DispatchPollingNotifier extends StateNotifier<OfficerStatus> {
  final Ref ref;
  Timer? _timer;
  int _failCount = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Officer ID from Hive auth state (fallback to 1 for dev)
  int get _officerId => Hive.box('settings').get('officer_id', defaultValue: 1);

  DispatchPollingNotifier(this.ref) : super(Offline());

  Future<void> goOnline() async {
    state = Online();
    _timer = Timer.periodic(const Duration(seconds: 3), _tick);
    await _tick(_timer!);
  }

  Future<void> goOffline() async {
    _timer?.cancel();
    _timer = null;
    state = Offline();
    
    // Attempt to notify server
    try {
      final dio = ref.read(dioProvider);
      final pos = await _getLocation();
      await dio.post(
        ApiEndpoints.ping(_officerId),
        data: {
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'status': 'offline',
        },
      );
    } catch (_) {}
  }

  Future<void> _tick(Timer t) async {
    try {
      final dio = ref.read(dioProvider);
      
      // 1. Ping location
      final pos = await _getLocation();
      await dio.post(
        ApiEndpoints.ping(_officerId),
        data: {
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'status': 'available',
        },
      );

      // 2. Poll for dispatch ONLY if we are Online
      if (state is Online) {
        final res = await dio.get(ApiEndpoints.pollDispatch(_officerId));
        if (res.data['has_dispatch'] == true) {
          final dispatch = DispatchModel.fromJson(res.data['dispatch']);
          state = Dispatching(dispatch);
          
          // Triggers side effects via the router
          _triggerDispatchAlert();
        }
      }
      
      _failCount = 0;
    } catch (e) {
      _failCount++;
      if (_failCount >= 3) {
        // Show connection warning (could be handled via a separate warning provider)
        print("Connection warning");
      }
    }
  }
  
  void _triggerDispatchAlert() {
    HapticFeedback.heavyImpact();
    // Play sound from assets
    _audioPlayer.play(AssetSource('sounds/alert.mp3'));
  }

  Future<void> respondToDispatch(bool accept) async {
    if (state is! Dispatching) return;
    
    final currentDispatch = (state as Dispatching).dispatch;
    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        ApiEndpoints.respondDispatch(_officerId, currentDispatch.alertId),
        data: {'action': accept ? 'accept' : 'reject'},
      );

      if (accept) {
        state = Navigating(currentDispatch);
        ref.read(routerProvider).go('/map');
      } else {
        state = Online();
      }
    } catch (e) {
      print("Failed to respond to dispatch");
    }
  }

  Future<void> missDispatch() async {
    if (state is! Dispatching) return;
    
    // In Uber model, we may not need to explicitly notify the backend of a miss, 
    // or we can send a 'miss' action so the backend knows this officer ignored it.
    final currentDispatch = (state as Dispatching).dispatch;
    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        ApiEndpoints.respondDispatch(_officerId, currentDispatch.alertId),
        data: {'action': 'missed'},
      );
    } catch (_) {}
    
    state = Online();
  }

  void markArrived() {
    if (state is Navigating) {
      state = Arrived((state as Navigating).dispatch);
    }
  }

  Future<void> resolveDispatch(bool isFalseAlarm, String notes) async {
    if (state is! Arrived) return;
    
    final currentDispatch = (state as Arrived).dispatch;
    try {
      final dio = ref.read(dioProvider);
      final data = {'officer_notes': notes};
      if (isFalseAlarm) {
        await dio.patch(
          ApiEndpoints.falseAlarm(currentDispatch.alertId),
          data: data,
        );
      } else {
        await dio.patch(
          ApiEndpoints.resolveAlert(currentDispatch.alertId),
          data: data,
        );
      }
      state = Online();
    } catch (e) {
      print("Failed to resolve dispatch");
    }
  }

  Future<Position> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Position(longitude: 80.0850, latitude: 12.8785, timestamp: DateTime.now(), accuracy: 1, altitude: 1, heading: 1, speed: 1, speedAccuracy: 1, altitudeAccuracy: 1, headingAccuracy: 1); // Mock location
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Position(longitude: 80.0850, latitude: 12.8785, timestamp: DateTime.now(), accuracy: 1, altitude: 1, heading: 1, speed: 1, speedAccuracy: 1, altitudeAccuracy: 1, headingAccuracy: 1); // Mock
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return Position(longitude: 80.0850, latitude: 12.8785, timestamp: DateTime.now(), accuracy: 1, altitude: 1, heading: 1, speed: 1, speedAccuracy: 1, altitudeAccuracy: 1, headingAccuracy: 1); // Mock
    }

    try {
      return await Geolocator.getCurrentPosition();
    } catch (e) {
      return Position(longitude: 80.0850, latitude: 12.8785, timestamp: DateTime.now(), accuracy: 1, altitude: 1, heading: 1, speed: 1, speedAccuracy: 1, altitudeAccuracy: 1, headingAccuracy: 1); // Mock fallback
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}

final dispatchProvider = StateNotifierProvider<DispatchPollingNotifier, OfficerStatus>((ref) {
  return DispatchPollingNotifier(ref);
});
