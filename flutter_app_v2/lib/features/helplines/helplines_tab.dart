import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/helpline_data.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../services/location_service.dart';
import '../../services/api_service.dart';
import '../../models/service_place.dart';
import 'helpline_category_page.dart';

class HelplinesTab extends StatefulWidget {
  const HelplinesTab({super.key});

  @override
  State<HelplinesTab> createState() => _HelplinesTabState();
}

class _HelplinesTabState extends State<HelplinesTab> {
  List<ServicePlace> _nearbyHospitals = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchNearbyHospitals();
    });
  }

  Future<void> _fetchNearbyHospitals() async {
    final locService = context.read<LocationService>();
    final apiService = context.read<ApiService>();

    if (locService.currentPosition == null) {
      await locService.getCurrentLocation();
    }

    if (locService.currentPosition == null) {
      if (mounted) {
        setState(() {
          _error = 'Location not available';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final hospitals = await apiService.getNearbyServices(
        latitude: locService.currentPosition!.latitude,
        longitude: locService.currentPosition!.longitude,
        serviceType: 'hospital',
      );
      
      if (mounted) {
        setState(() {
          _nearbyHospitals = hospitals.take(3).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load hospitals';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Helplines', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 4),
                const Text('Government of India official helplines', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                const SizedBox(height: 16),
                _buildNearbyHospitalsSection(),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: kHelplineCategories.length,
              itemBuilder: (context, index) {
                final category = kHelplineCategories[index];
                return GlassCard(
                  color: category.color,
                  icon: category.icon,
                  title: category.name,
                  subtitle: '${category.lines.length} numbers',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HelplineCategoryPage(category: category),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyHospitalsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_hospital_rounded, color: AppTheme.primaryRed, size: 20),
              const SizedBox(width: 8),
              const Text('Nearby Hospitals', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              if (_isLoading)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryRed)),
            ],
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppTheme.primaryRed, fontSize: 13))
          else if (!_isLoading && _nearbyHospitals.isEmpty)
            const Text('No hospitals found nearby.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13))
          else
            ..._nearbyHospitals.map((hospital) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(hospital.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14)),
                          Text(hospital.phone ?? 'No contact info', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        hospital.distanceLabel,
                        style: const TextStyle(color: AppTheme.primaryRed, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}
