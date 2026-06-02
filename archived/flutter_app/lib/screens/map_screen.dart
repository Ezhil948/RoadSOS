import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../services/offline_service.dart';
import '../models/service_place.dart';
import '../utils/constants.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<ServicePlace> _markers = [];
  String _activeType = 'hospital';

  static final _typeStyleMap = {
    for (final s in AppConstants.serviceTypes) s['key'] as String: s
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadServices());
  }

  Future<void> _loadServices() async {
    final loc = context.read<LocationService>();
    final api = context.read<ApiService>();
    final offline = context.read<OfflineService>();

    if (loc.currentPosition == null) return;

    final places = await api.getNearbyServices(
      latitude: loc.currentPosition!.latitude,
      longitude: loc.currentPosition!.longitude,
      serviceType: _activeType,
      offlineService: offline,
    );
    setState(() => _markers = places);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocationService>();
    final pos = loc.currentPosition;
    final center = pos != null
        ? LatLng(pos.latitude, pos.longitude)
        : const LatLng(13.0827, 80.2707); // Chennai default

    return Column(
      children: [
        // Service type filter chips
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            itemCount: AppConstants.serviceTypes.length,
            itemBuilder: (ctx, i) {
              final svc = AppConstants.serviceTypes[i];
              final isActive = _activeType == svc['key'];
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text('${svc['icon']} ${svc['label']}'),
                  selected: isActive,
                  onSelected: (_) {
                    setState(() => _activeType = svc['key']);
                    _loadServices();
                  },
                ),
              );
            },
          ),
        ),

        Expanded(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14.0,
            ),
            children: [
              // OpenStreetMap tile layer — free, no API key
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.roadsos.app',
                maxNativeZoom: 19,
              ),

              // Current location marker
              if (pos != null)
                MarkerLayer(markers: [
                  Marker(
                    point: LatLng(pos.latitude, pos.longitude),
                    width: 48,
                    height: 48,
                    child: const Icon(Icons.my_location,
                      color: Colors.blue, size: 32),
                  ),
                ]),

              // Service markers
              MarkerLayer(
                markers: _markers.map((place) {
                  final svc = _typeStyleMap[place.type] ?? {'color': 0xFFD32F2F, 'icon': '📍'};
                  return Marker(
                    point: LatLng(place.latitude, place.longitude),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => _showPlaceDetails(place),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color(svc['color']),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text(svc['icon'],
                            style: const TextStyle(fontSize: 18)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPlaceDetails(ServicePlace place) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(place.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(place.address ?? 'Address unavailable',
              style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text('Distance: ${place.distanceLabel}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
            if (place.phone != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.call),
                label: Text('Call: ${place.phone}'),
                onPressed: () {/* launch tel: URL */},
              ),
            ],
          ],
        ),
      ),
    );
  }
}
