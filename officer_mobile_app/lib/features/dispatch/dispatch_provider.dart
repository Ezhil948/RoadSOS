import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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
  final int? backupAlertId;
  Navigating(this.dispatch, {this.backupAlertId});
}
class Arrived extends OfficerStatus {      // resolve/false alarm
  final DispatchModel dispatch;
  final int? backupAlertId;
  Arrived(this.dispatch, {this.backupAlertId});
}

class DispatchPollingNotifier extends StateNotifier<OfficerStatus> {
  final Ref ref;
  Timer? _timer; // No longer used for periodic, but keeping for compatibility or we can remove
  bool _isPolling = false;
  int _failCount = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSub;
  WebSocketChannel? _wsChannel;

  // Officer ID from Hive auth state (fallback to 1 for dev)
  int get _officerId => Hive.box('settings').get('officer_id', defaultValue: 1);

  DispatchPollingNotifier(this.ref) : super(Offline());

  Future<void> goOnline() async {
    // Initial fetch to ensure permissions and location services are ready
    _currentPosition = await _fetchRealLocation(); 
    
    // Subscribe to passive stream for battery efficiency
    _positionStreamSub?.cancel();
    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5)
    ).listen((pos) {
      _currentPosition = pos;
    });

    state = Online();
    _isPolling = true;
    _pollLoop();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    _wsChannel?.sink.close();
    final wsUrl = ApiEndpoints.wsDispatch(_officerId);
    _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _wsChannel?.stream.listen((message) {
      if (message is String) {
        try {
          final data = jsonDecode(message);
          if (data['type'] == 'DISPATCH_INCOMING' || data['type'] == 'DISPATCH_CANCELLED') {
            _fetchDispatch();
          } else if (data['type'] == 'ALERT_CANCELLED_FALSE_ALARM') {
            state = Online();
            HapticFeedback.heavyImpact();
            ref.read(falseAlarmEventProvider.notifier).state = true;
          }
        } catch (_) {}
      }
    }, onError: (e) {
      print('WebSocket error: $e');
    }, onDone: () {
      print('WebSocket closed. Reconnecting...');
      if (_isPolling) {
        Future.delayed(const Duration(seconds: 5), _connectWebSocket);
      }
    });
  }

  Future<void> _pollLoop() async {
    if (!_isPolling) return;
    await _tick();
    if (_isPolling) {
      // Wait 10 seconds for location ping to save battery and network
      Future.delayed(const Duration(seconds: 10), _pollLoop);
    }
  }

  Future<void> goOffline() async {
    _isPolling = false;
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
    _wsChannel?.sink.close();
    _wsChannel = null;
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

  Future<void> _tick() async {
    try {
      final dio = ref.read(dioProvider);
      
      // 1. Ping location (0ms grab from memory)
      final pos = await _getLocation();
      String statusStr = 'available';
      if (state is Offline) statusStr = 'offline';
      else if (state is Navigating) statusStr = 'navigating';
      else if (state is Dispatching) statusStr = 'dispatching';
      else if (state is Arrived) statusStr = 'arrived';
      
      await dio.post(
        ApiEndpoints.ping(_officerId),
        data: {
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'status': statusStr,
        },
      );

      // 2. Poll backup status if active
      if (state is Navigating) {
        final navState = state as Navigating;
        if (navState.backupAlertId != null) {
          final bRes = await dio.get(ApiEndpoints.getAlertStatus(navState.backupAlertId!));
          if (bRes.data['status'] == 'cancelled_by_police') {
             // CRITICAL: Check if we are still Navigating before blindly overwriting state
             if (state is Navigating) {
               state = Navigating((state as Navigating).dispatch, backupAlertId: null);
               HapticFeedback.vibrate();
               print("Your backup request was cancelled by another officer.");
             }
          }
        }
      }
      
      // 3. Fallback: Always poll for dispatches in case WebSocket drops
      await _fetchDispatch();
      
      _failCount = 0;
    } catch (e) {
      _failCount++;
      if (_failCount >= 3) {
        print("Connection warning: $e");
      }
    }
  }

  Future<void> _fetchDispatch() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(ApiEndpoints.pollDispatch(_officerId));
      
      if (state is Online && res.data['has_dispatch'] == true) {
        final dispatchMap = res.data['dispatch'];
        final dispatch = DispatchModel.fromJson(dispatchMap);
        state = Dispatching(dispatch);
        _triggerDispatchAlert();
      } else if (state is Navigating) {
        final currentDispatch = (state as Navigating).dispatch;
        if (res.data['has_dispatch'] == false) {
          state = Online();
          _onAlertCancelled(currentDispatch.alertId);
        } else if (res.data['has_dispatch'] == true) {
          final dispatchMap = res.data['dispatch'];
          if (dispatchMap['location_update_pending'] == true) {
            final newLat = dispatchMap['new_lat'];
            final newLng = dispatchMap['new_lng'];
            if (newLat != null && newLng != null && currentDispatch.newLat == null) {
              final updatedDispatch = currentDispatch.copyWith(
                locationUpdatePending: true,
                newLat: newLat,
                newLng: newLng,
              );
              state = Navigating(updatedDispatch, backupAlertId: (state as Navigating).backupAlertId);
              HapticFeedback.heavyImpact();
            }
          }
        }
      } else if (state is Dispatching && res.data['has_dispatch'] == false) {
          state = Online();
          HapticFeedback.vibrate();
      }
    } catch (e) {
      print("Fetch dispatch error: $e");
    }
  }

  void _onAlertCancelled(int alertId) {
    // Notify via haptic — actual UI SnackBar shown in home_screen listening to state
    HapticFeedback.mediumImpact();
    print("Alert #$alertId was cancelled by citizen. Returning to standby.");
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
      if (!accept) {
        state = Online();
      }
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

  Future<void> markArrived() async {
    if (state is Navigating) {
      final currentDispatch = (state as Navigating).dispatch;
      state = Arrived(currentDispatch);
      
      try {
        final dio = ref.read(dioProvider);
        final pos = await _getLocation();
        await dio.post(
          ApiEndpoints.ping(_officerId),
          data: {
            'latitude': pos.latitude,
            'longitude': pos.longitude,
            'status': 'arrived',
          },
        );
      } catch (e) {
        print("Failed to explicitly notify backend of arrival");
      }
    }
  }

  Future<void> resolveDispatch(bool isFalseAlarm, String notes, [List<String>? photos, String? category]) async {
    if (state is! Arrived) return;
    
    final currentDispatch = (state as Arrived).dispatch;
    try {
      final dio = ref.read(dioProvider);
      
      if (isFalseAlarm) {
        final data = {'officer_notes': notes};
        await dio.patch(
          ApiEndpoints.falseAlarm(currentDispatch.alertId),
          data: data,
        );
      } else {
        final data = {
          'officer_notes': notes,
          if (category != null) 'category': category,
          if (photos != null && photos.isNotEmpty) 'photos': photos,
        };
        await dio.post(
          '${ApiEndpoints.baseUrl}/sos/alerts/${currentDispatch.alertId}/close',
          data: data,
        );
      }
      state = Online();
    } catch (e) {
      print("Failed to resolve dispatch");
    }
  }

  Future<void> requestBackup(String? message) async {
    try {
      final dio = ref.read(dioProvider);
      final pos = await _getLocation();
      final res = await dio.post(ApiEndpoints.requestBackup(_officerId), data: {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        if (message != null) 'message': message,
      });
      final backupAlertId = res.data['alert_id'];
      
      if (state is Navigating) {
        state = Navigating((state as Navigating).dispatch, backupAlertId: backupAlertId);
      } else if (state is Arrived) {
        state = Arrived((state as Arrived).dispatch, backupAlertId: backupAlertId);
      }
    } catch (e) {
      print("Failed to request backup: $e");
    }
  }

  Future<void> cancelDispatchByPolice(String reason, String? details) async {
    int? alertId;
    if (state is Dispatching) alertId = (state as Dispatching).dispatch.alertId;
    else if (state is Navigating) alertId = (state as Navigating).dispatch.alertId;
    else if (state is Arrived) alertId = (state as Arrived).dispatch.alertId;
    
    if (alertId == null) return;
    
    try {
      final dio = ref.read(dioProvider);
      await dio.post(ApiEndpoints.cancelByPolice(alertId), data: {
        'reason': reason,
        if (details != null) 'details': details,
      });
      state = Online();
    } catch (e) {
      print("Failed to cancel dispatch: $e");
    }
  }

  Future<Position> _getLocation() async {
    if (_currentPosition != null) {
      return _currentPosition!;
    }
    return await _fetchRealLocation();
  }

  Future<Position> _fetchRealLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions permanently denied.');
    }

    try {
      return await Geolocator.getCurrentPosition();
    } catch (e) {
      throw Exception('Could not get live location.');
    }
  }

  @override
  void dispose() {
    _isPolling = false;
    _positionStreamSub?.cancel();
    _wsChannel?.sink.close();
    _audioPlayer.dispose();
    super.dispose();
  }
}

final dispatchProvider = StateNotifierProvider<DispatchPollingNotifier, OfficerStatus>((ref) {
  return DispatchPollingNotifier(ref);
});

final falseAlarmEventProvider = StateProvider<bool>((ref) => false);
