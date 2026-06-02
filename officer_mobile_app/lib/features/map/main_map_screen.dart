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

  void _showResolveSheet(int alertId) {
    String? selectedCategory;
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF12121A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                const Text('MARK INCIDENT CLEAR', style: TextStyle(
                  color: Color(0xFF30D158), fontWeight: FontWeight.bold,
                  fontSize: 16, letterSpacing: 1.2,
                )),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Incident Category',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'accident', child: Text('Road Accident')),
                    DropdownMenuItem(value: 'medical', child: Text('Medical Emergency')),
                    DropdownMenuItem(value: 'crime', child: Text('Criminal Activity')),
                    DropdownMenuItem(value: 'traffic', child: Text('Traffic Incident')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (val) => setModalState(() => selectedCategory = val),
                  value: selectedCategory,
                  hint: const Text('Select category'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Resolution Notes',
                    hintText: 'Describe how the incident was resolved...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedCategory == null ? null : () {
                      Navigator.pop(ctx);
                      ref.read(dispatchProvider.notifier).resolveDispatch(
                        false,
                        notesController.text,
                        null,
                        selectedCategory,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF30D158),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('CONFIRM — MARK CLEAR',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStandDownSheet(int alertId) {
    final reasonController = TextEditingController();
    bool showReasonField = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF12121A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                const Text('STAND DOWN — SELECT REASON', style: TextStyle(
                  color: Color(0xFFFF3B30), fontWeight: FontWeight.bold,
                  fontSize: 16, letterSpacing: 1.2,
                )),
                const SizedBox(height: 20),
                // Option 1: False Alarm
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9F0A).withOpacity(0.1),
                    border: Border.all(color: const Color(0xFFFF9F0A).withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9F0A)),
                    title: const Text('FALSE ALARM', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF9F0A))),
                    subtitle: const Text('The emergency did not exist or was mistaken', style: TextStyle(fontSize: 12)),
                    onTap: () {
                      Navigator.pop(ctx);
                      ref.read(dispatchProvider.notifier).resolveDispatch(true, 'false_alarm');
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Option 2: Cannot Pursue
                if (!showReasonField)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withOpacity(0.1),
                      border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.block, color: Color(0xFFFF3B30)),
                      title: const Text('CANNOT RESPOND', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF3B30))),
                      subtitle: const Text('Circumstances prevent me from attending this incident', style: TextStyle(fontSize: 12)),
                      onTap: () => setModalState(() => showReasonField = true),
                    ),
                  ),
                if (showReasonField) ...[
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    autofocus: true,
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Reason for standing down',
                      hintText: 'e.g. Higher priority incident, road blocked...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: reasonController.text.trim().isEmpty ? null : () {
                        Navigator.pop(ctx);
                        ref.read(dispatchProvider.notifier).cancelDispatchByPolice(
                          'cannot_respond', reasonController.text.trim());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF3B30),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('CONFIRM STAND DOWN',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
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
              
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showResolveSheet(dispatch!.alertId),
                      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                      label: const Text('MARK CLEAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF30D158),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showStandDownSheet(dispatch!.alertId),
                      icon: const Icon(Icons.block, color: Colors.white),
                      label: const Text('STAND DOWN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF3B30),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
