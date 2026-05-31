import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/app_theme.dart';
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
    final isDark = true; // Forcing dark theme to match screenshot

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF111114),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF1A1A1D),
          indicatorColor: Colors.transparent,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF111114),
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('RoadSOS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: Colors.white)),
              Text('Emergency Response', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            ],
          ),
          actions: [
            if (!api.isOnline)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.wifi_off, color: Colors.amber),
              ),
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    const Text('Location Active', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.person, color: Colors.grey),
              onPressed: () {},
            ),
          ],
        ),
        body: Column(
          children: [
            if (!api.isOnline) const OfflineBanner(),
            Expanded(child: _getContent()),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.warning_amber_rounded, color: _selectedIndex == 0 ? Colors.red : Colors.grey), 
              label: 'Emergency'
            ),
            NavigationDestination(
              icon: Icon(Icons.phone, color: _selectedIndex == 1 ? Colors.white : Colors.grey), 
              label: 'Helplines'
            ),
            NavigationDestination(
              icon: Icon(Icons.location_on, color: _selectedIndex == 2 ? Colors.white : Colors.grey), 
              label: 'Nearby'
            ),
          ],
        ),
      ),
    );
  }

  Widget _getContent() {
    switch (_selectedIndex) {
      case 1: return const MapScreen(); // Re-use maps/helplines logic
      case 2: return const MapScreen();
      default: return _buildHome();
    }
  }

  Widget _buildHome() {
    final loc = context.watch<LocationService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. SOS Big Circular Button Area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1D),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.05),
                  blurRadius: 40,
                  spreadRadius: 10,
                )
              ]
            ),
            child: Column(
              children: [
                // Real implementation of SOSButton from screenshot
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFFF0453D), Color(0xFFD32F2F)],
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 5),
                      BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10, blurStyle: BlurStyle.inner),
                    ],
                  ),
                  child: const Center(
                    child: Text('SOS', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Hold to activate', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
              ],
            ),
          ),
          
          const SizedBox(height: 16),

          // 2. Live Location Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1D),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on, color: Colors.green, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Live Location Active', style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      loc.currentPosition != null 
                        ? '${loc.currentPosition!.latitude.toStringAsFixed(4)}, ${loc.currentPosition!.longitude.toStringAsFixed(4)}'
                        : 'Fetching...',
                      style: TextStyle(color: Colors.grey.shade500, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text('Quick Actions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // 3. Quick Actions Row
          Row(
            children: [
              _buildQuickAction(Icons.local_police, 'Call\nPolice', Colors.blue, '100'),
              const SizedBox(width: 12),
              _buildQuickAction(Icons.local_hospital, 'Call\nAmbulance', Colors.green, '108'),
              const SizedBox(width: 12),
              _buildQuickAction(Icons.local_fire_department, 'Call\nFire Brigade', Colors.red, '101'),
            ],
          ),

          const SizedBox(height: 16),

          // 4. File Accident Report Button
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccidentReportScreen())),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt, color: Colors.orange),
                  const SizedBox(width: 12),
                  const Text('File Accident Report', style: TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Text('Safety Reminders', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // 5. Safety Reminder
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1D),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.self_improvement, color: Colors.orange),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Stay Calm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Take a deep breath. Panicking worsens the situation. Assess injuries first before acting.', 
                        style: TextStyle(color: Colors.grey.shade400, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color, String phoneNumber) {
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          final uri = Uri.parse('tel:$phoneNumber');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
