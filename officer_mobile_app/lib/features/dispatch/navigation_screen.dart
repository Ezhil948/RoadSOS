import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import 'dispatch_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../widgets/components.dart';
import '../../widgets/slide_to_confirm.dart';

// Provider to hold the notes added during navigation
final dispatchNoteProvider = StateProvider<String>((ref) => '');

class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _pulsingController;
  
  LatLng? _officerPosition;
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = true;
  bool _autoCenter = true;
  
  Timer? _centerTimer;
  StreamSubscription<Position>? _positionStreamSub;
  
  int _remainingSeconds = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    
    _pulsingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1500),
    )..repeat(reverse: true);

    // Initial position fetch
    _initLocationTracking();

    // Start auto center timer
    _centerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_autoCenter && _officerPosition != null) {
        _mapController.move(_officerPosition!, 15.0);
      }
    });
  }

  void _initLocationTracking() async {
    // Get current dispatch to start countdown
    final status = ref.read(dispatchProvider);
    if (status is Navigating) {
      _startLiveCountdown(status.dispatch.etaMins);
    }

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
        _loadRoute();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location unavailable. Route map will not load until permission granted.')));
      }
    }

    // Subscribe to location updates
    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((Position pos) {
      if (mounted) {
        setState(() {
          _officerPosition = LatLng(pos.latitude, pos.longitude);
        });
      }
    });
  }

  void _startLiveCountdown(int initialMins) {
    _remainingSeconds = initialMins * 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          }
        });
      }
    });
  }

  Future<void> _loadRoute() async {
    final status = ref.read(dispatchProvider);
    if (status is! Navigating || _officerPosition == null) return;
    
    setState(() {
      _isLoadingRoute = true;
    });

    final dest = LatLng(status.dispatch.latitude, status.dispatch.longitude);
    final points = await _fetchRoute(_officerPosition!, dest);
    
    if (mounted) {
      setState(() {
        _routePoints = points;
        _isLoadingRoute = false;
      });
    }
  }

  Future<List<LatLng>> _fetchRoute(LatLng start, LatLng end) async {
    try {
      final dio = Dio();
      final url = 'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson';
      final response = await dio.get(url);
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
          return coordinates.map((c) => LatLng(c[1] as double, c[0] as double)).toList();
        }
      }
    } catch (e) {
      print('Error fetching OSRM route: $e');
    }
    // Fallback to straight line
    return [start, end];
  }

  void _refreshRoute() {
    _loadRoute();
    final status = ref.read(dispatchProvider);
    if (status is Navigating) {
      _startLiveCountdown(status.dispatch.etaMins);
    }
  }

  void _reCenter() {
    setState(() {
      _autoCenter = true;
    });
    if (_officerPosition != null) {
      _mapController.move(_officerPosition!, 15.0);
    }
  }

  void _showAddNoteDialog() {
    final noteController = TextEditingController(text: ref.read(dispatchNoteProvider));
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? kDarkSurface : kLightSurface,
          title: Text('// ADD DISPATCH NOTE', style: AppTheme.monoMd.copyWith(color: kAccentGreen)),
          content: TextField(
            controller: noteController,
            maxLines: 4,
            style: AppTheme.monoSm.copyWith(color: isDark ? kDarkText : kLightText),
            decoration: InputDecoration(
              hintText: 'Enter description or observations...',
              hintStyle: TextStyle(color: isDark ? kDarkMuted : kLightMuted),
              filled: true,
              fillColor: isDark ? kDarkBg : kLightBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: isDark ? kDarkBorder : kLightBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: kAccentGreen),
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? kDarkText : kLightText,
                side: BorderSide(color: isDark ? kDarkBorder : kLightBorder),
              ),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(dispatchNoteProvider.notifier).state = noteController.text;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Note updated locally'),
                    backgroundColor: kAccentGreenDim,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
  }

  void _onArrive() async {
    // Notify server of arrival
    final status = ref.read(dispatchProvider);
    if (status is Navigating) {
      try {
        final dio = ref.read(dioProvider);
        // Call status endpoint if it exists, wrap in try-catch to avoid crashing if it 404s
        await dio.post(
          ApiEndpoints.ping(1), // Fallback status update via ping
          data: {
            'latitude': _officerPosition?.latitude ?? 12.8785,
            'longitude': _officerPosition?.longitude ?? 80.0850,
            'status': 'arrived',
          },
        );
      } catch (_) {}
    }

    ref.read(dispatchProvider.notifier).markArrived();
    if (mounted) {
      context.pushReplacement('/dispatch/resolve');
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '00:00';
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _pulsingController.dispose();
    _centerTimer?.cancel();
    _positionStreamSub?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(dispatchProvider);
    if (status is! Navigating) {
      return const Scaffold(backgroundColor: kDarkBg, body: Center(child: CircularProgressIndicator()));
    }

    final dispatch = status.dispatch;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bgColor = isDark ? kDarkBg : kLightBg;
    final surfaceColor = isDark ? kDarkSurface : kLightSurface;
    final borderColor = isDark ? kDarkBorder : kLightBorder;
    final textColor = isDark ? kDarkText : kLightText;
    final subtextColor = isDark ? kDarkSubtext : kLightSubtext;
    final mutedColor = isDark ? kDarkMuted : kLightMuted;

    final dest = LatLng(dispatch.latitude, dispatch.longitude);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Map
            if (_officerPosition != null)
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _officerPosition!,
                  initialZoom: 15.0,
                  onPositionChanged: (position, hasGesture) {
                    if (hasGesture && _autoCenter) {
                      setState(() {
                        _autoCenter = false;
                      });
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
                      // Officer Position (Blue Pulsing Marker)
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
                                      decoration: BoxDecoration(
                                        color: kAccentBlue.withOpacity(0.4),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: const BoxDecoration(
                                        color: kAccentBlue,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      // Destination Position (Red Marker)
                      Marker(
                        point: dest,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: kAccentRed,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              const Center(child: CircularProgressIndicator()),

            // 56dp AppBar Overlay over Map
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: bgColor.withOpacity(0.9),
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          color: textColor,
                          onPressed: () => context.go('/'),
                        ),
                        const SizedBox(width: 8),
                        Text('DISPATCH #${dispatch.alertId}', style: AppTheme.monoMd.copyWith(color: textColor)),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: _reCenter,
                      icon: Icon(Icons.my_location, size: 16, color: _autoCenter ? kAccentGreen : textColor),
                      label: Text('RE-CENTER', style: AppTheme.monoSm.copyWith(color: _autoCenter ? kAccentGreen : textColor)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Note FAB
            Positioned(
              right: 16,
              bottom: 240, // Above persistent sheet
              child: FloatingActionButton.small(
                onPressed: _showAddNoteDialog,
                backgroundColor: surfaceColor,
                foregroundColor: kAccentGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(color: borderColor),
                ),
                child: const Icon(Icons.edit_note),
              ),
            ),

            // persistent bottom sheet
            Align(
              alignment: Alignment.bottomCenter,
              child: DraggableScrollableSheet(
                initialChildSize: 0.28,
                minChildSize: 0.18,
                maxChildSize: 0.45,
                snap: true,
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      border: Border(top: BorderSide(color: borderColor)),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Drag Handle
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: borderColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        
                        // Victim header & Call button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('VICTIM INFORMATION', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                            TextButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Calling features are disabled in this test build.'),
                                    backgroundColor: kAccentRed,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.phone, size: 16, color: kAccentRed),
                              label: Text('CALL (DISABLED)', style: AppTheme.monoSm.copyWith(color: kAccentRed)),
                              style: TextButton.styleFrom(
                                side: const BorderSide(color: kAccentRed, width: 0.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        Text('Name: [REDACTED]', style: AppTheme.monoSm.copyWith(color: textColor)),
                        const SizedBox(height: 4),
                        Text('Phone: +91 98XXXXXX82', style: AppTheme.monoSm.copyWith(color: textColor)),
                        const SizedBox(height: 4),
                        Text('Notes: Unconscious, breathing', style: AppTheme.monoSm.copyWith(color: subtextColor)),
                        const SizedBox(height: 16),
                        
                        Divider(color: borderColor),
                        const SizedBox(height: 16),
                        
                        // ETA, Distance, and Refresh Route
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            MonoMetric(
                              value: _formatDuration(_remainingSeconds),
                              label: 'ETA COUNTDOWN',
                            ),
                            MonoMetric(
                              value: '${dispatch.distanceKm} KM',
                              label: 'DISTANCE',
                            ),
                            IconButton(
                              onPressed: _refreshRoute,
                              icon: _isLoadingRoute 
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: kAccentGreen),
                                    )
                                  : const Icon(Icons.refresh, color: kAccentGreen),
                              tooltip: 'Refresh Route',
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Slide to confirm
                        SlideToConfirm(
                          onConfirm: _onArrive,
                          label: 'SLIDE TO ARRIVE >>',
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
