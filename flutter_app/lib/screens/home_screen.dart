import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/app_theme.dart';
import '../widgets/service_card.dart';
import '../widgets/sos_button.dart';
import '../widgets/offline_banner.dart';
import 'services_list_screen.dart';
import 'map_screen.dart';
import 'accident_report_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final loc = context.watch<LocationService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('RoadSOS', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (!api.isOnline)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.wifi_off, color: Colors.amber),
            ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () => loc.getCurrentLocation(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!api.isOnline) const OfflineBanner(),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.camera_alt), label: 'Report'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        // Premium subtle gradient background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      const Color(0xFF141416),
                      const Color(0xFF1E1E22),
                    ]
                  : [
                      const Color(0xFFFDFBFB),
                      const Color(0xFFEBEDEE),
                    ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        // Subtle colored blobs for glassmorphism pop
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryRed.withValues(alpha: isDark ? 0.12 : 0.08),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          left: -50,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.safeGreen.withValues(alpha: isDark ? 0.12 : 0.08),
            ),
          ),
        ),
        // Main Content
        SafeArea(
          child: _getContent(),
        ),
      ],
    );
  }

  Widget _getContent() {
    switch (_selectedIndex) {
      case 1: return const MapScreen();
      case 2: return const AccidentReportScreen();
      default: return _buildHome();
    }
  }

  Widget _buildHome() {
    final loc = context.watch<LocationService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SOS Big Button
          const SOSButton(),
          const SizedBox(height: 32),

          // Location info
          if (loc.currentPosition != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: AppTheme.safeGreen, size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Current Location', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                      Text(
                        '${loc.currentPosition!.latitude.toStringAsFixed(4)}, '
                        '${loc.currentPosition!.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),
          const Text('Emergency Services',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 16),

          // Service grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: AppConstants.serviceTypes.length,
            itemBuilder: (ctx, i) {
              final svc = AppConstants.serviceTypes[i];
              return ServiceCard(
                label: svc['label'],
                icon: svc['icon'],
                color: Color(svc['color']),
                onTap: () {
                  Navigator.push(ctx, MaterialPageRoute(
                    builder: (_) => ServicesListScreen(
                      serviceType: svc['key'],
                      serviceLabel: svc['label'],
                      serviceColor: Color(svc['color']),
                    ),
                  ));
                },
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
