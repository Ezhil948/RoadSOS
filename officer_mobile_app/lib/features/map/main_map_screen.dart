import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';

import '../../core/theme/app_theme.dart';
import '../../features/dispatch/dispatch_provider.dart';

class MainMapScreen extends ConsumerStatefulWidget {
  const MainMapScreen({super.key});

  @override
  ConsumerState<MainMapScreen> createState() => _MainMapScreenState();
}

class _MainMapScreenState extends ConsumerState<MainMapScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _pulsingController;
  
  LatLng? _officerPosition;
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = false;
  bool _autoCenter = true;
  
  StreamSubscription<Position>? _positionStreamSub;

  @override
  void initState() {
    super.initState();
    _pulsingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _initLocationTracking();
  }

  void _initLocationTracking() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _officerPosition = LatLng(pos.latitude, pos.longitude);
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location unavailable. Map will not load until permission granted.')));
      }
    }

    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((Position pos) {
      if (mounted) {
        setState(() {
          _officerPosition = LatLng(pos.latitude, pos.longitude);
        });
        if (_autoCenter) {
          _mapController.move(_officerPosition!, 15.0);
        }
      }
    });
  }

  Future<void> _loadRoute(LatLng destination) async {
    if (_officerPosition == null) return;
    
    setState(() { _isLoadingRoute = true; });

    try {
      final dio = Dio();
      final url = 'https://router.project-osrm.org/route/v1/driving/${_officerPosition!.longitude},${_officerPosition!.latitude};${destination.longitude},${destination.latitude}?geometries=geojson';
      final response = await dio.get(url);
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
          if (mounted) {
            setState(() {
              _routePoints = coordinates.map((c) => LatLng(c[1] as double, c[0] as double)).toList();
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _routePoints = [_officerPosition!, destination];
        });
      }
    } finally {
      if (mounted) {
        setState(() { _isLoadingRoute = false; });
      }
    }
  }

  void _reCenter() {
    setState(() { _autoCenter = true; });
    if (_officerPosition != null) {
      _mapController.move(_officerPosition!, 15.0);
    }
  }

  void _requestBackup() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup requested successfully.'), backgroundColor: kAccentBlue),
    );
  }

  void _callAmbulance() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ambulance dispatched to location.'), backgroundColor: kAccentAmber),
    );
  }

  @override
  void dispose() {
    _pulsingController.dispose();
    _positionStreamSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(dispatchProvider);
    final isNavigating = status is Navigating;
    
    LatLng? destination;
    if (isNavigating) {
      destination = LatLng(status.dispatch.latitude, status.dispatch.longitude);
      if (_routePoints.isEmpty && !_isLoadingRoute) {
        _loadRoute(destination);
      }
    } else {
      if (_routePoints.isNotEmpty) {
        // Clear route if no longer navigating
        Future.microtask(() => setState(() => _routePoints = []));
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? kDarkBg : kLightBg;
    final surfaceColor = isDark ? kDarkSurface : kLightSurface;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(isNavigating ? 'Navigating to Scene' : 'Patrol Map', style: AppTheme.monoMd),
        actions: [
          IconButton(
            icon: Icon(Icons.my_location, color: _autoCenter ? kAccentBlue : (isDark ? Colors.white : Colors.black)),
            onPressed: _reCenter,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_officerPosition != null)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _officerPosition!,
                initialZoom: 15.0,
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture && _autoCenter) {
                    setState(() => _autoCenter = false);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.roadsos.officer',
                ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        color: kAccentBlue,
                        strokeWidth: 4.0,
                        pattern: StrokePattern.dashed(segments: [6, 4]),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    // Officer Position
                    Marker(
                      point: _officerPosition!,
                      width: 32,
                      height: 32,
                      child: AnimatedBuilder(
                        animation: _pulsingController,
                        builder: (context, child) {
                          final pulseValue = 1.0 + (_pulsingController.value * 0.3);
                          return Center(
                            child: Stack(
                              children: [
                                Center(
                                  child: Container(
                                    width: 20 * pulseValue,
                                    height: 20 * pulseValue,
                                    decoration: BoxDecoration(color: kAccentBlue.withOpacity(0.4), shape: BoxShape.circle),
                                  ),
                                ),
                                Center(
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      color: kAccentBlue,
                                      shape: BoxShape.circle,
                                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    if (destination != null)
                      Marker(
                        point: destination,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_on, color: kAccentRed, size: 40),
                      ),
                  ],
                ),
              ],
            )
          else
            const Center(child: CircularProgressIndicator()),

          // Action Buttons (Backup, Ambulance) when navigating
          if (isNavigating)
            Positioned(
              right: 16,
              bottom: 32,
              child: Column(
                children: [
                  FloatingActionButton(
                    heroTag: 'backup_btn',
                    onPressed: _requestBackup,
                    backgroundColor: surfaceColor,
                    child: const Icon(Icons.local_police, color: kAccentBlue),
                  ),
                  const SizedBox(height: 16),
                  FloatingActionButton(
                    heroTag: 'ambulance_btn',
                    onPressed: _callAmbulance,
                    backgroundColor: surfaceColor,
                    child: const Icon(Icons.medical_services, color: kAccentRed),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
