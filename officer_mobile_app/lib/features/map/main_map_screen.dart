import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';

import '../../core/theme/app_theme.dart';
import '../../features/dispatch/dispatch_provider.dart';
import '../../core/models/dispatch.dart';

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
    // Show confirmation modal
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? kDarkSurface : kLightSurface,
        title: Text('REQUEST BACKUP?', style: AppTheme.monoMd.copyWith(color: kAccentBlue)),
        content: const Text('Broadcast an urgent backup request to all nearby officers?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(dispatchProvider.notifier).requestBackup(null);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backup request broadcasted securely.'), backgroundColor: kAccentBlue),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: kAccentBlue),
            child: const Text('BROADCAST', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCancelAlertOptions(int alertId) {
    String? selectedReason;
    final TextEditingController detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).brightness == Brightness.dark ? kDarkSurface : kLightSurface,
              title: const Text('Cancel Alert', style: TextStyle(color: kAccentRed, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select reason for cancellation:'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'false_alarm', child: Text('False Alarm')),
                      DropdownMenuItem(value: 'resolved_on_scene', child: Text('Resolved on scene')),
                      DropdownMenuItem(value: 'duplicate_alert', child: Text('Duplicate alert')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        selectedReason = val;
                      });
                    },
                    value: selectedReason,
                    hint: const Text('Reason'),
                  ),
                  if (selectedReason == 'other') ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: detailsController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter details (required)',
                      ),
                      onChanged: (v) => setState(() {}),
                      maxLines: 2,
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('BACK'),
                ),
                ElevatedButton(
                  onPressed: (selectedReason != null && (selectedReason != 'other' || detailsController.text.isNotEmpty))
                      ? () {
                          Navigator.pop(ctx);
                          final reason = selectedReason == 'other' ? detailsController.text : selectedReason!;
                          ref.read(dispatchProvider.notifier).cancelDispatchByPolice(reason, detailsController.text);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(backgroundColor: kAccentRed),
                  child: const Text('CONFIRM CANCEL', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
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
    
    DispatchModel? dispatch;
    LatLng? destination;
    if (isNavigating) {
      dispatch = status.dispatch;
      destination = LatLng(dispatch.latitude, dispatch.longitude);
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
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.roadsos.officer',
                  retinaMode: MediaQuery.of(context).devicePixelRatio > 1.0,
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

          // Action Buttons (Backup) when navigating
          if (isNavigating)
            Positioned(
              right: 16,
              bottom: dispatch?.type == 'officer_backup' ? 100 : 300, // adjust based on panel height
              child: FloatingActionButton(
                heroTag: 'backup_btn',
                onPressed: _requestBackup,
                backgroundColor: surfaceColor,
                child: const Icon(Icons.local_police, color: kAccentBlue),
              ),
            ),
            
          // Incident Details Panel
          if (isNavigating && dispatch != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildIncidentDetailsPanel(dispatch),
            ),
        ],
      ),
    );
  }

  Widget _buildIncidentDetailsPanel(DispatchModel dispatch) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? kDarkSurface : kLightSurface;
    final textColor = isDark ? kDarkText : kLightText;
    final mutedColor = isDark ? kDarkMuted : kLightMuted;
    
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black26, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dispatch.type == 'officer_backup' ? 'OFFICER BACKUP' : 'INCIDENT DETAILS', style: AppTheme.monoMd.copyWith(color: dispatch.type == 'officer_backup' ? kAccentBlue : kAccentRed, fontWeight: FontWeight.bold)),
                  if (dispatch.reporters.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: kAccentAmber.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                      child: Text('${dispatch.reporters.length} REPORTS COMBINED', style: AppTheme.monoSm.copyWith(color: kAccentAmber, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              
              Text(dispatch.type == 'officer_backup' ? 'REQUESTING OFFICER' : 'REPORTERS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: mutedColor)),
              const SizedBox(height: 8),
              if (dispatch.type == 'officer_backup')
                Chip(
                  avatar: const Icon(Icons.local_police, size: 16, color: kAccentBlue),
                  label: Text(dispatch.officerName ?? 'Unknown Officer', style: TextStyle(color: textColor, fontSize: 12)),
                  backgroundColor: kAccentBlue.withOpacity(0.1),
                  side: BorderSide.none,
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: dispatch.reporters.isEmpty 
                    ? [Chip(label: const Text('Anonymous'), backgroundColor: isDark ? kDarkBg : kLightBg, side: BorderSide.none)]
                    : dispatch.reporters.map((r) => Chip(
                        avatar: const Icon(Icons.person, size: 16),
                        label: Text(r, style: TextStyle(color: textColor, fontSize: 12)),
                        backgroundColor: isDark ? kDarkBg : kLightBg,
                        side: BorderSide.none,
                      )).toList(),
                ),
              
              if (dispatch.photos.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('ATTACHED PHOTOS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: mutedColor)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: dispatch.photos.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 80,
                        decoration: BoxDecoration(
                          color: kDarkMuted,
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(dispatch.photos[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showCancelAlertOptions(dispatch.alertId),
                  icon: const Icon(Icons.cancel, color: Colors.white),
                  label: const Text('CANCEL ALERT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentRed, 
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              ),
            ],
          ),
        ),
      ),
    );
  }
}
