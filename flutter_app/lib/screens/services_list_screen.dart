import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../services/offline_service.dart';
import '../models/service_place.dart';
import '../widgets/offline_banner.dart';
import '../utils/dialog_utils.dart';

class ServicesListScreen extends StatefulWidget {
  final String serviceType;
  final String serviceLabel;
  final Color serviceColor;

  const ServicesListScreen({
    super.key,
    required this.serviceType,
    required this.serviceLabel,
    required this.serviceColor,
  });

  @override
  State<ServicesListScreen> createState() => _ServicesListScreenState();
}

class _ServicesListScreenState extends State<ServicesListScreen> {
  List<ServicePlace> _places = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    setState(() { _loading = true; _error = null; });

    final loc = context.read<LocationService>();
    final api = context.read<ApiService>();
    final offline = context.read<OfflineService>();

    if (loc.currentPosition == null) {
      await loc.getCurrentLocation();
    }

    if (loc.currentPosition == null) {
      setState(() { _loading = false; _error = 'Cannot get location'; });
      return;
    }

    try {
      final places = await api.getNearbyServices(
        latitude: loc.currentPosition!.latitude,
        longitude: loc.currentPosition!.longitude,
        serviceType: widget.serviceType,
        offlineService: offline,
      );
      setState(() { _places = places; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Nearest ${widget.serviceLabel}'),
        backgroundColor: widget.serviceColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchServices,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!api.isOnline) const OfflineBanner(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchServices, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_places.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('No services found nearby.'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchServices, child: const Text('Try wider area')),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _places.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _PlaceTile(
        place: _places[i],
        color: widget.serviceColor,
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  final ServicePlace place;
  final Color color;

  const _PlaceTile({required this.place, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(Icons.location_on, color: color),
        ),
        title: Text(place.name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(place.address ?? 'Address not available',
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Row(
              children: [
                Icon(Icons.directions, size: 14, color: color),
                const SizedBox(width: 4),
                Text(place.distanceLabel,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                if (place.isCached) ...[
                  const SizedBox(width: 8),
                  const Chip(
                    label: Text('Cached', style: TextStyle(fontSize: 10)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: place.phone != null
          ? IconButton(
              icon: Icon(Icons.call, color: color),
              onPressed: () {
                /*
                final uri = Uri.parse('tel:${place.phone}');
                if (await canLaunchUrl(uri)) launchUrl(uri);
                */
                DialogUtils.showSimulatedCallDialog(context, place.name, place.phone!);
              },
            )
          : null,
        onTap: () {
          // Navigate to map focused on this place
        },
      ),
    );
  }
}
