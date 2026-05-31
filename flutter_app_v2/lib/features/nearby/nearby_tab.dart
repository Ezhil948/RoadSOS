import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../services/location_service.dart';
import '../../services/api_service.dart';
import '../../models/service_place.dart';

class NearbyTab extends StatefulWidget {
  const NearbyTab({super.key});
  @override
  State<NearbyTab> createState() => _NearbyTabState();
}

class _NearbyTabState extends State<NearbyTab> {
  final MapController _mapController = MapController();
  List<ServicePlace> _markers = [];
  String _activeType = 'hospital';
  bool _loading = false;
  bool _showResults = false;

  static const List<Map<String, dynamic>> _serviceTypes = [
    {'key': 'hospital',  'label': 'Hospital',      'emoji': '🏥', 'color': AppTheme.primaryRed},
    {'key': 'police',    'label': 'Police',         'emoji': '🚔', 'color': AppTheme.accentBlue},
    {'key': 'ambulance', 'label': 'Ambulance',      'emoji': '🚑', 'color': AppTheme.accentGreen},
    {'key': 'towing',    'label': 'Towing',         'emoji': '🚛', 'color': AppTheme.accentPurple},
    {'key': 'puncture',  'label': 'Tyre Shop',      'emoji': '🔧', 'color': AppTheme.accentTeal},
    {'key': 'showroom',  'label': 'Showroom',       'emoji': '🏪', 'color': AppTheme.accentAmber},
  ];

  static final _typeStyleMap = {
    for (final s in _serviceTypes) s['key'] as String: s
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadServices());
  }

  Future<void> _loadServices() async {
    final loc = context.read<LocationService>();
    final api = context.read<ApiService>();
    if (loc.currentPosition == null) return;

    setState(() { _loading = true; _showResults = false; });

    final places = await api.getNearbyServices(
      latitude: loc.currentPosition!.latitude,
      longitude: loc.currentPosition!.longitude,
      serviceType: _activeType,
    );

    setState(() {
      _markers = places;
      _loading = false;
      _showResults = places.isNotEmpty;
    });
  }

  Color get _activeColor => (_typeStyleMap[_activeType]?['color'] as Color?) ?? AppTheme.primaryRed;
  String get _activeEmoji => (_typeStyleMap[_activeType]?['emoji'] as String?) ?? '📍';

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocationService>();
    final pos = loc.currentPosition;
    final center = pos != null
        ? LatLng(pos.latitude, pos.longitude)
        : const LatLng(13.0827, 80.2707);

    return SafeArea(
      child: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: center, initialZoom: 14.0),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                  userAgentPackageName: 'com.roadsos.citizen_v2',
                  maxNativeZoom: 19,
                ),
                if (pos != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: LatLng(pos.latitude, pos.longitude),
                      width: 52, height: 52,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.accentBlue.withOpacity(0.25),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.accentBlue, width: 2),
                        ),
                        child: const Icon(Icons.my_location_rounded, color: AppTheme.accentBlue, size: 26),
                      ),
                    ),
                  ]),
                MarkerLayer(
                  markers: _markers.map((place) {
                    final svc = _typeStyleMap[place.type] ?? {'color': AppTheme.primaryRed, 'emoji': '📍'};
                    final color = svc['color'] as Color;
                    return Marker(
                      point: LatLng(place.latitude, place.longitude),
                      width: 46, height: 46,
                      child: GestureDetector(
                        onTap: () => _showPlaceDetails(place),
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10)],
                          ),
                          child: Center(child: Text(svc['emoji'] as String, style: const TextStyle(fontSize: 20))),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // ── Top: Filter chips ─────────────────────────────────────────────
          Positioned(
            top: 12,
            left: 0, right: 0,
            child: SizedBox(
              height: 52,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _serviceTypes.length,
                itemBuilder: (ctx, i) {
                  final svc = _serviceTypes[i];
                  final isActive = _activeType == svc['key'];
                  final color = svc['color'] as Color;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _activeType = svc['key']);
                        _loadServices();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isActive ? color : AppTheme.surfaceDark.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: isActive ? color : AppTheme.borderDark, width: 1.5),
                          boxShadow: isActive
                              ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: 12)]
                              : [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(svc['emoji'] as String, style: const TextStyle(fontSize: 15)),
                            const SizedBox(width: 6),
                            Text(
                              svc['label'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isActive ? Colors.white : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Location permission banner ─────────────────────────────────────
          if (!loc.hasPermission)
            Positioned(
              bottom: 24,
              left: 20, right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.accentAmber.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_off_rounded, color: AppTheme.accentAmber),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Enable location to find nearby services',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final locService = context.read<LocationService>();
                        await locService.requestPermission();
                        if (locService.hasPermission) {
                          await locService.getCurrentLocation();
                          _loadServices();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Enable', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Loading spinner ───────────────────────────────────────────────
          if (_loading)
            const Positioned(
              bottom: 100,
              left: 0, right: 0,
              child: Center(child: CircularProgressIndicator(color: AppTheme.primaryRed)),
            ),

          // ── Results count pill ──────────────────────────────────────────
          if (!_loading && _markers.isNotEmpty && loc.hasPermission)
            Positioned(
              bottom: 24,
              left: 20, right: 20,
              child: GestureDetector(
                onTap: () => _showResultsList(),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _activeColor.withOpacity(0.4)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20)],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: _activeColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: Text(_activeEmoji, style: const TextStyle(fontSize: 20))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_markers.length} ${_typeStyleMap[_activeType]?['label'] ?? 'places'} found nearby',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            Text(
                              'Closest: ${_markers.first.distanceLabel} away',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.expand_less_rounded, color: _activeColor),
                    ],
                  ),
                ),
              ),
            ),

          // ── No results hint ─────────────────────────────────────────────
          if (!_loading && _markers.isEmpty && loc.hasPermission)
            Positioned(
              bottom: 24,
              left: 20, right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppTheme.textMuted),
                    SizedBox(width: 12),
                    Text('No results found nearby. Try a different category.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showResultsList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.borderDark, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(_activeEmoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(
                    '${_typeStyleMap[_activeType]?['label'] ?? 'Nearby'} (${_markers.length})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                itemCount: _markers.length,
                itemBuilder: (ctx, i) => _buildResultItem(_markers[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultItem(ServicePlace place) {
    final color = (_typeStyleMap[place.type]?['color'] as Color?) ?? AppTheme.primaryRed;
    return GestureDetector(
      onTap: () => _showPlaceDetails(place),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(place.distanceLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color, fontFamily: 'monospace')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (place.address != null)
                    Text(place.address!, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (place.phone != null)
              IconButton(
                icon: Icon(Icons.phone_rounded, color: color, size: 20),
                onPressed: () async {
                  final uri = Uri(scheme: 'tel', path: place.phone);
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showPlaceDetails(ServicePlace place) {
    final color = (_typeStyleMap[place.type]?['color'] as Color?) ?? AppTheme.primaryRed;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(place.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 4),
            Text(place.address ?? 'Address unavailable', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text('📍 ${place.distanceLabel}', style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13)),
                ),
              ],
            ),
            if (place.phone != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.phone_rounded),
                  label: Text('Call ${place.phone}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final uri = Uri(scheme: 'tel', path: place.phone);
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
