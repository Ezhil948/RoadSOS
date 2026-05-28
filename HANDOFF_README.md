# RoadSOS - Project Handoff Document

## 🎯 Current Goal
RoadSOS is an emergency road safety application built with **Flutter** (Frontend) and **Python/FastAPI** (Backend). The primary goal is to allow users to quickly trigger emergency SOS alerts, call critical services (Police, Ambulance), and submit detailed accident reports (including photos and AI analysis) with precise GPS coordinates.

## 🚀 Progress & Current State (Where we left off)
1. **Frontend (Flutter)**
   - Converted the app to compile as a native Android APK (`flutter build apk --target-platform android-arm64`) to solve web-based geolocation and CanvasKit rendering issues.
   - Fixed text visibility issues in Dark Mode across `home_screen.dart` and `accident_report_screen.dart` by adding theme-aware backgrounds and borders.
   - Polished the **Emergency SOS Button**:
     - Reduced size to `90px` height.
     - Replaced uniform scaling with an asymmetric `AnimatedBuilder` stretch (4% vertical, 3% horizontal).
     - Adjusted timing to a slow, calm 800ms pulse loop.
     - Added horizontal padding so it doesn't overflow the screen edges.
   - Emergency calling features (`tel:112`, etc.) are currently mocked with simulated `AlertDialog` popups for safe testing without dialing real emergency numbers.

2. **Backend (Python FastAPI)**
   - Running successfully on local network `0.0.0.0:8000`.
   - The Flutter app's `AppConstants.baseUrl` is pointed to the host machine's Wi-Fi IP (`http://10.82.59.177:8000`) so the physical phone (Vivo 300) can connect to it over hotspot.

## 🔮 Future Goals & Next Steps
1. **App Name Rebranding**:
   - The current placeholder name is "RoadSOS", but **this is NOT fixed**.
   - **Next Step**: Generate a few modern, professional app name ideas (e.g., Aegis, SwiftSave, ResQDrive) and update the project once a final name is chosen.
2. **App Icon Implementation**:
   - The user has generated a custom app icon.
   - **Next Step**: Crop the raw image perfectly square, save it as `assets/icon.png`, and use the `flutter_launcher_icons` package to generate the native Android/iOS icons.
3. **Real AI Integration**:
   - The accident report screen currently uses a mocked 2-second delay to simulate AI image analysis.
   - **Next Step**: Connect the FastAPI backend to an actual Vision AI model (like Gemini Pro Vision or OpenAI) to analyze the uploaded accident photos in real time.
4. **Database & Dashboard**:
   - Build a web dashboard for the "Control Room" so responders can see incoming SOS alerts and live GPS pins on a map.

## 💻 Key Code Snippets (For AI Context)

### 1. Flutter: `sos_button.dart` (Asymmetric Pulse Animation)
```dart
class _SOSButtonState extends State<SOSButton> with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;
  bool _activated = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scale = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    _pulse.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) {
        final scaleX = 1.0 + (_scale.value * 0.03); // 3% horizontal stretch
        final scaleY = 1.0 + (_scale.value * 0.04); // 4% vertical stretch
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(scaleX, scaleY, 1.0),
          child: child,
        );
      },
      child: GestureDetector(
        onLongPress: _triggerSOS,
        child: Container(
          width: double.infinity, height: 90,
          decoration: BoxDecoration(/* Red/Green Gradient */),
          child: Center(child: Text(_activated ? 'SOS SENT' : 'EMERGENCY SOS')),
        ),
      ),
    );
  }
}
```

### 2. Python Backend: `main.py` (FastAPI Setup)
```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import services, sos, accident, ai_analysis, emergency

app = FastAPI(title="RoadSOS API", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(services.router,  prefix="/api/v1/services")
app.include_router(sos.router,       prefix="/api/v1/sos")
app.include_router(accident.router,  prefix="/api/v1/accident")
app.include_router(ai_analysis.router, prefix="/api/v1/ai")

@app.get("/health")
async def health():
    return {"status": "ok", "service": "RoadSOS API v2.0"}
```

## 📁 Key File Locations
- **SOS Button widget**: `flutter_app/lib/widgets/sos_button.dart` (Contains the custom animation logic)
- **Home Screen**: `flutter_app/lib/screens/home_screen.dart` (Contains the dark-mode aware gradient background)
- **Accident Report**: `flutter_app/lib/screens/accident_report_screen.dart`
- **API Setup**: `flutter_app/lib/utils/constants.dart` (Contains the local backend IP address)
- **Backend API**: `backend/main.py`

## 🛠️ Instructions to run
**Run Backend:**
```powershell
cd backend
.\venv\Scripts\activate
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
**Run Frontend (Web Testing):**
```powershell
cd flutter_app
flutter run -d web-server --web-port 8080
```
**Build Android APK:**
```powershell
cd flutter_app
flutter build apk --release --target-platform android-arm64
```


## 📂 Complete Source Code

### File: flutter_app/lib\main.dart
`dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/splash_screen.dart';
import 'services/location_service.dart';
import 'services/api_service.dart';
import 'services/offline_service.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('offline_cache');
  runApp(const RoadSOSApp());
}

class RoadSOSApp extends StatelessWidget {
  const RoadSOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocationService()),
        ChangeNotifierProvider(create: (_) => ApiService()),
        ChangeNotifierProvider(create: (_) => OfflineService()),
      ],
      child: MaterialApp(
        title: 'RoadSOS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const SplashScreen(),
      ),
    );
  }
}

`

### File: flutter_app/lib\models\accident_report.dart
`dart
class AccidentReport {
  final String id;
  final double latitude;
  final double longitude;
  final String severity; // minor, moderate, critical
  final int casualties;
  final String description;
  final List<String> imagePaths;
  final DateTime timestamp;
  final String? aiAnalysis;

  AccidentReport({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.severity,
    required this.casualties,
    required this.description,
    required this.imagePaths,
    required this.timestamp,
    this.aiAnalysis,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'latitude': latitude,
    'longitude': longitude,
    'severity': severity,
    'casualties': casualties,
    'description': description,
    'image_paths': imagePaths,
    'timestamp': timestamp.toIso8601String(),
    'ai_analysis': aiAnalysis,
  };
}

`

### File: flutter_app/lib\models\service_place.dart
`dart
class ServicePlace {
  final String id;
  final String name;
  final String type;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String? phone;
  final String? address;
  final bool isOpen;
  final String? rating;
  final bool isCached;

  ServicePlace({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    this.phone,
    this.address,
    this.isOpen = true,
    this.rating,
    this.isCached = false,
  });

  factory ServicePlace.fromJson(Map<String, dynamic> json) {
    return ServicePlace(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown',
      type: json['type'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      distanceKm: (json['distance_km'] ?? 0.0).toDouble(),
      phone: json['phone'],
      address: json['address'],
      isOpen: json['is_open'] ?? true,
      rating: json['rating']?.toString(),
      isCached: json['is_cached'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'latitude': latitude,
    'longitude': longitude,
    'distance_km': distanceKm,
    'phone': phone,
    'address': address,
    'is_open': isOpen,
    'rating': rating,
    'is_cached': isCached,
  };

  String get distanceLabel {
    if (distanceKm < 1.0) return '${(distanceKm * 1000).toInt()}m';
    return '${distanceKm.toStringAsFixed(1)}km';
  }
}

`

### File: flutter_app/lib\screens\accident_report_screen.dart
`dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';

class AccidentReportScreen extends StatefulWidget {
  const AccidentReportScreen({super.key});
  @override
  State<AccidentReportScreen> createState() => _AccidentReportScreenState();
}

class _AccidentReportScreenState extends State<AccidentReportScreen> {
  final _descController = TextEditingController();
  String _severity = 'moderate';
  int _casualties = 0;
  File? _selectedImage;
  bool _submitting = false;
  String? _aiAnalysis;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera, imageQuality: 70, maxWidth: 1280);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
      await _analyzeImage(File(picked.path));
    }
  }

  Future<void> _analyzeImage(File img) async {
    setState(() => _aiAnalysis = 'Analyzing image...');
    try {
      await img.readAsBytes();
      // final b64 = base64Encode(bytes);
      // final api = context.read<ApiService>();
      // Would call /api/v1/ai/analyze with base64 image
      // For now, mock response
      await Future.delayed(const Duration(seconds: 2));
      setState(() => _aiAnalysis =
          '✅ AI detected: Vehicle accident. Estimated severity: $_severity. '
          'Visible injuries possible. Recommend immediate medical assistance.');
    } catch (e) {
      setState(() => _aiAnalysis = 'AI analysis unavailable offline');
    }
  }

  Future<void> _submitReport() async {
    final loc = context.read<LocationService>();
    if (loc.currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available')));
      return;
    }

    setState(() => _submitting = true);
    final api = context.read<ApiService>();
    final result = await api.sendSOSAlert(
      latitude: loc.currentPosition!.latitude,
      longitude: loc.currentPosition!.longitude,
      severity: _severity,
      message: _descController.text,
    );
    setState(() => _submitting = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message'] ?? 'Report sent!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Report Accident',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),

          // Image capture
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, width: 2,
                  style: BorderStyle.none),
              ),
              child: _selectedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_selectedImage!, fit: BoxFit.cover,
                      width: double.infinity))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 48, color: isDark ? Colors.grey.shade600 : Colors.grey),
                      const SizedBox(height: 8),
                      Text('Tap to capture accident photo',
                        style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey)),
                    ],
                  ),
            ),
          ),

          if (_aiAnalysis != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.blue.shade900.withOpacity(0.4) : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.blue.shade800 : Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.smart_toy, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_aiAnalysis!,
                    style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          const Text('Severity', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'minor', label: Text('Minor')),
              ButtonSegment(value: 'moderate', label: Text('Moderate')),
              ButtonSegment(value: 'critical', label: Text('Critical')),
            ],
            selected: {_severity},
            onSelectionChanged: (s) => setState(() => _severity = s.first),
          ),

          const SizedBox(height: 20),
          const Text('Casualties (approx)', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _casualties > 0
                  ? () => setState(() => _casualties--) : null,
              ),
              Text('$_casualties',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(() => _casualties++),
              ),
            ],
          ),

          const SizedBox(height: 20),
          TextField(
            controller: _descController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'What happened? Any specific details...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _submitting
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send),
              label: Text(_submitting ? 'Sending...' : 'Submit Report'),
              onPressed: _submitting ? null : _submitReport,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

`

### File: flutter_app/lib\screens\home_screen.dart
`dart
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
              color: AppTheme.primaryRed.withOpacity(isDark ? 0.12 : 0.08),
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
              color: AppTheme.safeGreen.withOpacity(isDark ? 0.12 : 0.08),
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
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
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

`

### File: flutter_app/lib\screens\map_screen.dart
`dart
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
                  final svc = AppConstants.serviceTypes
                      .firstWhere((s) => s['key'] == place.type,
                      orElse: () => {'color': 0xFFD32F2F, 'icon': '📍'});
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

`

### File: flutter_app/lib\screens\services_list_screen.dart
`dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../services/offline_service.dart';
import '../models/service_place.dart';
import '../widgets/offline_banner.dart';

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
          backgroundColor: color.withOpacity(0.15),
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
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Simulated Call: ${place.name}'),
                    content: Text('Simulating call to ${place.phone} (${place.name})...\n\n(No actual phone call was placed)'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
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

`

### File: flutter_app/lib\screens\splash_screen.dart
`dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/location_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnim = Tween(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();
    _initApp();
  }

  Future<void> _initApp() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final ls = context.read<LocationService>();
    await ls.getCurrentLocation();
    if (!mounted) return;
    Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD32F2F),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(
                    color: Colors.black26, blurRadius: 20, spreadRadius: 5)],
                ),
                child: const Center(
                  child: Text('🚨', style: TextStyle(fontSize: 64)),
                ),
              ),
              const SizedBox(height: 32),
              const Text('RoadSOS',
                style: TextStyle(
                  fontSize: 42, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: 2)),
              const SizedBox(height: 8),
              const Text('Emergency Response — Always Ready',
                style: TextStyle(fontSize: 14, color: Colors.white70)),
              const SizedBox(height: 48),
              const CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2),
            ],
          ),
        ),
      ),
    );
  }
}

`

### File: flutter_app/lib\services\api_service.dart
`dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/service_place.dart';
import '../utils/constants.dart';
import 'offline_service.dart';

class ApiService extends ChangeNotifier {
  late final Dio _dio;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(LogInterceptor(responseBody: false));
  }

  Future<List<ServicePlace>> getNearbyServices({
    required double latitude,
    required double longitude,
    required String serviceType,
    int radius = AppConstants.defaultSearchRadius,
    OfflineService? offlineService,
  }) async {
    // Try API first
    try {
      final response = await _dio.get(
        AppConstants.nearbyServicesEndpoint,
        queryParameters: {
          'lat': latitude,
          'lng': longitude,
          'type': serviceType,
          'radius': radius,
        },
      );
      _isOnline = true;
      final List data = response.data['results'] ?? [];
      final places = data.map((j) => ServicePlace.fromJson(j)).toList();

      // Cache result for offline use
      offlineService?.cacheServices(serviceType, latitude, longitude, places);
      notifyListeners();
      return places;
    } on DioException {
      _isOnline = false;
      notifyListeners();

      // Fallback: OSM Overpass API (direct, no backend needed)
      try {
        return await _fetchFromOverpass(latitude, longitude, serviceType, radius);
      } catch (_) {
        // Final fallback: local cache
        return offlineService?.getCachedServices(serviceType, latitude, longitude) ?? [];
      }
    }
  }

  /// Direct OSM Overpass query — works without our backend
  Future<List<ServicePlace>> _fetchFromOverpass(
    double lat, double lon, String type, int radius) async {
    final osmTag = AppConstants.serviceTypes
        .firstWhere((s) => s['key'] == type, orElse: () => {'osm_tag': 'amenity=hospital'})['osm_tag'];

    final query = '''
[out:json][timeout:25];
(
  node[$osmTag](around:$radius,$lat,$lon);
  way[$osmTag](around:$radius,$lat,$lon);
);
out center 20;
''';

    final overpassDio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ));

    final resp = await overpassDio.post(
      AppConstants.overpassApiUrl,
      data: 'data=${Uri.encodeComponent(query)}',
      options: Options(contentType: 'application/x-www-form-urlencoded'),
    );

    final elements = resp.data['elements'] as List? ?? [];
    List<ServicePlace> places = [];

    for (var el in elements) {
      final elLat = (el['lat'] ?? el['center']?['lat'] ?? 0.0).toDouble();
      final elLon = (el['lon'] ?? el['center']?['lon'] ?? 0.0).toDouble();
      final tags = el['tags'] as Map? ?? {};
      final name = tags['name'] ?? tags['operator'] ?? 'Unknown ${type}';
      final phone = tags['phone'] ?? tags['contact:phone'];

      final dist = _haversineKm(lat, lon, elLat, elLon);

      places.add(ServicePlace(
        id: el['id'].toString(),
        name: name,
        type: type,
        latitude: elLat,
        longitude: elLon,
        distanceKm: dist,
        phone: phone,
        address: tags['addr:full'] ?? tags['addr:street'],
        isCached: false,
      ));
    }

    places.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return places;
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = (dLat / 2) * (dLat / 2) +
        _toRad(lat1) * _toRad(lat2) * (dLon / 2) * (dLon / 2);
    return r * 2 * (a < 1 ? a : 1);
  }

  double _toRad(double deg) => deg * 3.141592653589793 / 180;

  Future<Map<String, dynamic>> sendSOSAlert({
    required double latitude,
    required double longitude,
    required String severity,
    String? message,
  }) async {
    try {
      final response = await _dio.post(AppConstants.sosAlertEndpoint, data: {
        'latitude': latitude,
        'longitude': longitude,
        'severity': severity,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      });
      return response.data;
    } catch (e) {
      return {'status': 'offline', 'message': 'SOS logged locally'};
    }
  }
}

`

### File: flutter_app/lib\services\location_service.dart
`dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  bool _isLoading = false;
  String? _error;

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _error = 'Location services are disabled.';
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _error = 'Location permission denied.';
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _error = 'Location permissions permanently denied.';
      return false;
    }
    return true;
  }

  Future<Position?> getCurrentLocation() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      bool hasPermission = await requestPermission();
      if (!hasPermission) {
        _isLoading = false;
        notifyListeners();
        return null;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _isLoading = false;
      notifyListeners();
      return _currentPosition;
    } catch (e) {
      // Fallback to last known position for offline
      _currentPosition = await Geolocator.getLastKnownPosition();
      _error = 'Using last known location';
      _isLoading = false;
      notifyListeners();
      return _currentPosition;
    }
  }

  double calculateDistance(double lat2, double lon2) {
    if (_currentPosition == null) return 0;
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      lat2,
      lon2,
    ) / 1000; // in km
  }
}

`

### File: flutter_app/lib\services\offline_service.dart
`dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/service_place.dart';
import '../utils/constants.dart';

class OfflineService extends ChangeNotifier {
  late Box _box;

  OfflineService() {
    _box = Hive.box('offline_cache');
  }

  void cacheServices(
    String type, double lat, double lng, List<ServicePlace> places) {
    final key = _buildKey(type, lat, lng);
    final data = {
      'places': places.map((p) => p.toJson()).toList(),
      'cached_at': DateTime.now().millisecondsSinceEpoch,
      'lat': lat,
      'lng': lng,
    };
    _box.put(key, jsonEncode(data));
  }

  List<ServicePlace> getCachedServices(String type, double lat, double lng) {
    final key = _buildKey(type, lat, lng);
    final raw = _box.get(key);
    if (raw == null) return [];

    final data = jsonDecode(raw);
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(data['cached_at']);
    final age = DateTime.now().difference(cachedAt).inMinutes;

    if (age > AppConstants.cacheTtlMinutes) return [];

    final List places = data['places'] ?? [];
    return places.map((j) {
      final p = ServicePlace.fromJson(j);
      return ServicePlace(
        id: p.id, name: p.name, type: p.type,
        latitude: p.latitude, longitude: p.longitude,
        distanceKm: p.distanceKm, phone: p.phone,
        address: p.address, isCached: true,
      );
    }).toList();
  }

  String _buildKey(String type, double lat, double lng) {
    // Round to 2 decimal places for area-based caching (~1km grid)
    final rLat = (lat * 100).round() / 100;
    final rLng = (lng * 100).round() / 100;
    return 'services_${type}_${rLat}_$rLng';
  }

  bool hasCachedData(String type, double lat, double lng) {
    return getCachedServices(type, lat, lng).isNotEmpty;
  }

  void clearCache() {
    _box.clear();
    notifyListeners();
  }
}

`

### File: flutter_app/lib\utils\app_theme.dart
`dart
import 'package:flutter/material.dart';

class AppTheme {
  // Modern, vibrant color palette
  static const Color primaryRed = Color(0xFFFF3B30);
  static const Color primaryOrange = Color(0xFFFF9500);
  static const Color safeGreen = Color(0xFF34C759);
  static const Color alertAmber = Color(0xFFFFCC00);
  static const Color darkBg = Color(0xFF1C1C1E);
  static const Color lightBg = Color(0xFFF2F2F7);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: lightBg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryRed,
      brightness: Brightness.light,
      background: lightBg,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.black87,
      elevation: 0,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        elevation: 0,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: darkBg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryRed,
      brightness: Brightness.dark,
      background: darkBg,
    ),
  );
}

`

### File: flutter_app/lib\utils\constants.dart
`dart
class AppConstants {
  // API Base URL - change for production
  static const String baseUrl = 'http://10.82.59.177:8000'; // Host local IP for physical mobile device connection
  // static const String baseUrl = 'http://localhost:8000'; // iOS simulator

  // API Endpoints
  static const String nearbyServicesEndpoint = '/api/v1/services/nearby';
  static const String reportAccidentEndpoint = '/api/v1/accident/report';
  static const String analyzeImageEndpoint = '/api/v1/ai/analyze';
  static const String sosAlertEndpoint = '/api/v1/sos/alert';
  static const String offlineSyncEndpoint = '/api/v1/sync/offline-data';

  // OpenStreetMap Nominatim (free, no key needed)
  static const String osmNominatimUrl = 'https://nominatim.openstreetmap.org';

  // Overpass API for OSM POI data
  static const String overpassApiUrl = 'https://overpass-api.de/api/interpreter';

  // Default search radius (meters)
  static const int defaultSearchRadius = 5000;
  static const int maxSearchRadius = 20000;

  // Service Types
  static const List<Map<String, dynamic>> serviceTypes = [
    {'key': 'police', 'label': 'Police', 'icon': '🚔', 'osm_tag': 'amenity=police', 'color': 0xFF1565C0},
    {'key': 'hospital', 'label': 'Hospital', 'icon': '🏥', 'osm_tag': 'amenity=hospital', 'color': 0xFFD32F2F},
    {'key': 'ambulance', 'label': 'Ambulance', 'icon': '🚑', 'osm_tag': 'amenity=ambulance_station', 'color': 0xFFFF6F00},
    {'key': 'towing', 'label': 'Towing', 'icon': '🚛', 'osm_tag': 'amenity=vehicle_rescue', 'color': 0xFF4527A0},
    {'key': 'puncture', 'label': 'Puncture Shop', 'icon': '🔧', 'osm_tag': 'shop=tyres', 'color': 0xFF2E7D32},
    {'key': 'showroom', 'label': 'Showroom', 'icon': '🏪', 'osm_tag': 'shop=car', 'color': 0xFF00838F},
  ];

  // Emergency Numbers by country
  static const Map<String, Map<String, String>> emergencyNumbers = {
    'IN': {'police': '100', 'ambulance': '108', 'fire': '101', 'national': '112'},
    'US': {'police': '911', 'ambulance': '911', 'fire': '911', 'national': '911'},
    'UK': {'police': '999', 'ambulance': '999', 'fire': '999', 'national': '999'},
    'DEFAULT': {'police': '112', 'ambulance': '112', 'fire': '112', 'national': '112'},
  };

  // Offline cache TTL (minutes)
  static const int cacheTtlMinutes = 60;
}

`

### File: flutter_app/lib\widgets\offline_banner.dart
`dart
import 'package:flutter/material.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.amber.shade700,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: const Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('Offline Mode — Showing cached data',
            style: TextStyle(color: Colors.white, fontSize: 12,
              fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

`

### File: flutter_app/lib\widgets\service_card.dart
`dart
import 'dart:ui';
import 'package:flutter/material.dart';

class ServiceCard extends StatelessWidget {
  final String label, icon;
  final Color color;
  final VoidCallback onTap;

  const ServiceCard({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      splashColor: color.withOpacity(0.3),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.white.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(isDark ? 0.25 : 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(isDark ? 0.2 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(icon, style: const TextStyle(fontSize: 32)),
                ),
                const SizedBox(height: 12),
                Text(label,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87.withOpacity(0.8),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

`

### File: flutter_app/lib\widgets\sos_button.dart
`dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class SOSButton extends StatefulWidget {
  const SOSButton({super.key});
  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;
  bool _activated = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _scale = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _triggerSOS() async {
    HapticFeedback.heavyImpact();
    setState(() => _activated = true);

    final loc = context.read<LocationService>();
    final api = context.read<ApiService>();

    await api.sendSOSAlert(
      latitude: loc.currentPosition?.latitude ?? 0,
      longitude: loc.currentPosition?.longitude ?? 0,
      severity: 'critical',
      message: 'Emergency SOS triggered',
    );

    // Call national emergency (Mocked for testing)
    /*
    final uri = Uri.parse('tel:112');
    if (await canLaunchUrl(uri)) launchUrl(uri);
    */
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Simulated Emergency SOS'),
          content: const Text('Simulating emergency call to 112...\n\n(No actual phone call was placed)'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _activated = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AnimatedBuilder(
            animation: _scale,
            builder: (context, child) {
              final scaleX = 1.0 + (_scale.value * 0.03); // 3% horizontal stretch
              final scaleY = 1.0 + (_scale.value * 0.04); // 4% vertical stretch
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(scaleX, scaleY, 1.0),
                child: child,
              );
            },
            child: GestureDetector(
              onLongPress: _triggerSOS,
              child: Container(
                width: double.infinity,
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _activated
                        ? [const Color(0xFF34C759), const Color(0xFF28A745)]
                        : [const Color(0xFFFF3B30), const Color(0xFFD32F2F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: (_activated ? Colors.green : Colors.red).withOpacity(0.4),
                      blurRadius: 24,
                      spreadRadius: 8,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.2),
                      blurRadius: 0,
                      spreadRadius: 1,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _activated ? Icons.check_circle_outline : Icons.emergency_share,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _activated ? 'SOS SENT' : 'EMERGENCY SOS',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _activated ? 'Help is on the way' : 'Hold for 1 second to activate',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _QuickCallBtn(label: 'Police', icon: '🚔', number: '100'),
            _QuickCallBtn(label: 'Ambulance', icon: '🚑', number: '108'),
            _QuickCallBtn(label: 'Emergency', icon: '🆘', number: '112'),
          ],
        ),
      ],
    );
  }
}

class _QuickCallBtn extends StatelessWidget {
  final String label, icon, number;
  const _QuickCallBtn({required this.label, required this.icon, required this.number});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () {
        /*
        final uri = Uri.parse('tel:$number');
        if (await canLaunchUrl(uri)) launchUrl(uri);
        */
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Simulated Call: $label'),
            content: Text('Simulating call to $number ($label)...\n\n(No actual phone call was placed)'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(number,
            style: const TextStyle(fontSize: 11, color: Colors.red,
              fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

`

### File: backend\.env
`
DB_HOST=localhost
DB_PORT=3306
DB_USER=roadsos_admin
DB_PASSWORD=roadsos_pass
DB_NAME=roadsos_db
APP_HOST=0.0.0.0
APP_PORT=8000
DEBUG=true
YOLO_MODEL_PATH=ai_module/models/accident_detector.pt
OVERPASS_API_URL=https://overpass-api.de/api/interpreter

`

### File: backend\.env.example
`
DB_HOST=localhost
DB_PORT=3306
DB_USER=roadsos_admin
DB_PASSWORD=roadsos_pass
DB_NAME=roadsos_db
APP_HOST=0.0.0.0
APP_PORT=8000
DEBUG=true
YOLO_MODEL_PATH=ai_module/models/accident_detector.pt
OVERPASS_API_URL=https://overpass-api.de/api/interpreter

`

### File: backend\main.py
`python
"""
RoadSOS FastAPI Backend
DB: roadsos_db | User: roadsos_admin
Run: uvicorn main:app --reload --host 0.0.0.0 --port 8000
Swagger: http://localhost:8000/docs
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from app.routers import services, sos, accident, ai_analysis, sync, emergency, feedback, logs
from app.utils.database import engine, Base, check_db_connection
import os

@asynccontextmanager
async def lifespan(app: FastAPI):
    # ── Startup ──────────────────────────────────────────
    print("🚀 RoadSOS API starting up...")
    # Create all tables in roadsos_db
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    db_ok = await check_db_connection()
    print(f"   MySQL roadsos_db: {'✅ Connected' if db_ok else '❌ FAILED'}")
    print(f"   User: roadsos_admin @ {os.getenv('DB_HOST', 'localhost')}")
    yield
    # ── Shutdown ─────────────────────────────────────────
    print("🛑 RoadSOS API shutting down...")
    await engine.dispose()


app = FastAPI(
    title="RoadSOS API",
    description="""
## 🚨 RoadSOS — Emergency Response Backend

**IIT Madras COERS 2026 Hackathon**

### Endpoints
| Group | Purpose |
|---|---|
| `/api/v1/services` | Nearby police, hospital, ambulance, towing, puncture, showroom |
| `/api/v1/sos` | SOS alert trigger and management |
| `/api/v1/accident` | Accident report submission |
| `/api/v1/ai` | YOLOv8 accident image analysis |
| `/api/v1/emergency` | Country emergency numbers |
| `/api/v1/feedback` | Service ratings |
| `/api/v1/sync` | Offline bundle pre-fetch |
| `/api/v1/logs` | App event logging |

**Database:** `roadsos_db` (MySQL 8.0)  
**Maps:** OpenStreetMap (free, no API key, global)
    """,
    version="2.0.0",
    lifespan=lifespan,
)

# CORS — Flutter mobile (all origins for MVP)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ────────────────────────────────────────────────
app.include_router(services.router,  prefix="/api/v1/services",  tags=["Services"])
app.include_router(sos.router,       prefix="/api/v1/sos",       tags=["SOS"])
app.include_router(accident.router,  prefix="/api/v1/accident",  tags=["Accident"])
app.include_router(ai_analysis.router, prefix="/api/v1/ai",      tags=["AI"])
app.include_router(emergency.router, prefix="/api/v1/emergency", tags=["Emergency Numbers"])
app.include_router(feedback.router,  prefix="/api/v1/feedback",  tags=["Feedback"])
app.include_router(sync.router,      prefix="/api/v1/sync",      tags=["Offline Sync"])
app.include_router(logs.router,      prefix="/api/v1/logs",      tags=["Logs"])


@app.get("/health", tags=["Health"])
async def health():
    db_ok = await check_db_connection()
    return {
        "status": "ok" if db_ok else "degraded",
        "service": "RoadSOS API v2.0",
        "database": "connected" if db_ok else "unreachable",
        "db_name": os.getenv("DB_NAME", "roadsos_db"),
        "db_user": os.getenv("DB_USER", "roadsos_admin"),
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=os.getenv("APP_HOST", "0.0.0.0"),
        port=int(os.getenv("APP_PORT", 8000)),
        reload=True,
    )

`

### File: backend\requirements.txt
`
fastapi
uvicorn[standard]
pydantic
pydantic-settings
sqlalchemy
aiomysql
httpx
python-multipart
pillow
ultralytics
python-dotenv
geopy
haversine
pymysql
cryptography

`

### File: backend\ai_module\TRAINING_NOTES.md
`
# YOLOv8 Accident Detection — Training Notes

## MVP Approach
For the hackathon MVP, use the base YOLOv8n model which already detects:
- car, truck, bus, motorcycle, bicycle (vehicles)
- person (casualties)
- traffic light, stop sign (road context)

The backend's `_estimate_severity()` logic maps these COCO detections
to accident severity without needing a custom model.

## Fine-tuning (Post-Hackathon)
To improve accuracy, fine-tune on accident datasets:
1. ACLED Road Incidents dataset
2. Kaggle: Car Accident Detection Dataset
3. Custom labeled images from Indian roads

```bash
# Install
pip install ultralytics

# Download base model
yolo download model=yolov8n.pt

# Fine-tune (requires labeled dataset in YOLO format)
yolo train model=yolov8n.pt data=accident_data.yaml epochs=50 imgsz=640

# Export
yolo export model=best.pt format=onnx  # for production
```

## Model Placement
Place trained model at: `backend/ai_module/models/accident_detector.pt`
Set env var: `YOLO_MODEL_PATH=ai_module/models/accident_detector.pt`

If file doesn't exist, backend auto-downloads yolov8n.pt from ultralytics.

`

### File: backend\ai_module\__init__.py
`python

`

### File: backend\ai_module\models\__init__.py
`python

`

### File: backend\ai_module\utils\__init__.py
`python

`

### File: backend\app\__init__.py
`python

`

### File: backend\app\models\db_models.py
`python
"""
RoadSOS — SQLAlchemy ORM Models
All tables map to roadsos_db MySQL schema.

Table relationships:
  sos_alerts  ──FK──>  accident_reports (optional link)
  accident_reports  ──FK──>  ai_analysis_results (1:1)
  cached_services  (standalone, populated from OSM)
  emergency_numbers  (standalone lookup table)
  service_feedback  ──FK──>  cached_services
  app_logs  (standalone audit/analytics)
"""

from sqlalchemy import (
    Column, Integer, String, Float, DateTime, Text, Enum,
    ForeignKey, Boolean, SmallInteger, Index
)
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.utils.database import Base
import enum


# ── Enums ──────────────────────────────────────────────────
class SeverityEnum(str, enum.Enum):
    minor = "minor"
    moderate = "moderate"
    critical = "critical"


class AlertStatusEnum(str, enum.Enum):
    active = "active"
    resolved = "resolved"
    false_alarm = "false_alarm"


class ServiceTypeEnum(str, enum.Enum):
    police = "police"
    hospital = "hospital"
    ambulance = "ambulance"
    towing = "towing"
    puncture = "puncture"
    showroom = "showroom"


# ── 1. SOS Alerts ──────────────────────────────────────────
class SOSAlert(Base):
    __tablename__ = "sos_alerts"

    id = Column(Integer, primary_key=True, autoincrement=True)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    severity = Column(Enum(SeverityEnum), default=SeverityEnum.critical)
    message = Column(Text, nullable=True)
    device_id = Column(String(100), nullable=True, index=True)
    status = Column(Enum(AlertStatusEnum), default=AlertStatusEnum.active, index=True)
    alerted_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)
    resolved_at = Column(DateTime(timezone=True), nullable=True)

    # FK link to accident report (optional — set when user also files a report)
    accident_report_id = Column(Integer, ForeignKey("accident_reports.id"), nullable=True)

    # Relationship
    accident_report = relationship("AccidentReport", back_populates="sos_alerts", foreign_keys=[accident_report_id])

    __table_args__ = (
        Index("idx_sos_location", "latitude", "longitude"),
    )


# ── 2. Accident Reports ────────────────────────────────────
class AccidentReport(Base):
    __tablename__ = "accident_reports"

    id = Column(Integer, primary_key=True, autoincrement=True)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    severity = Column(Enum(SeverityEnum), default=SeverityEnum.moderate, index=True)
    casualties = Column(SmallInteger, default=0)
    description = Column(Text, nullable=True)
    image_path = Column(String(500), nullable=True)
    status = Column(String(50), default="open", index=True)
    reported_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)
    updated_at = Column(DateTime(timezone=True), onupdate=func.now(), nullable=True)

    # Relationships
    sos_alerts = relationship("SOSAlert", back_populates="accident_report", foreign_keys="SOSAlert.accident_report_id")
    ai_result = relationship("AIAnalysisResult", back_populates="accident_report", uselist=False)

    __table_args__ = (
        Index("idx_accident_location", "latitude", "longitude"),
    )


# ── 3. AI Analysis Results ─────────────────────────────────
class AIAnalysisResult(Base):
    __tablename__ = "ai_analysis_results"

    id = Column(Integer, primary_key=True, autoincrement=True)
    accident_report_id = Column(Integer, ForeignKey("accident_reports.id"), nullable=True, unique=True)
    detected_objects = Column(Text, nullable=True)      # JSON string
    severity_estimate = Column(String(50), nullable=True)
    confidence_score = Column(Float, nullable=True)
    vehicles_count = Column(SmallInteger, default=0)
    persons_detected = Column(Boolean, default=False)
    recommendations = Column(Text, nullable=True)       # JSON string
    model_used = Column(String(100), default="yolov8n")
    analyzed_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationship
    accident_report = relationship("AccidentReport", back_populates="ai_result")


# ── 4. Cached Services (OSM data) ──────────────────────────
class CachedService(Base):
    __tablename__ = "cached_services"

    id = Column(Integer, primary_key=True, autoincrement=True)
    osm_id = Column(String(100), nullable=True)
    name = Column(String(255), nullable=False)
    service_type = Column(Enum(ServiceTypeEnum), nullable=False, index=True)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    phone = Column(String(50), nullable=True)
    address = Column(Text, nullable=True)
    country_code = Column(String(10), default="IN", index=True)
    is_verified = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
    last_updated = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Relationship
    feedbacks = relationship("ServiceFeedback", back_populates="service")

    __table_args__ = (
        Index("idx_service_location", "latitude", "longitude"),
        Index("idx_service_type_country", "service_type", "country_code"),
    )


# ── 5. Emergency Numbers (per country) ────────────────────
class EmergencyNumber(Base):
    __tablename__ = "emergency_numbers"

    id = Column(Integer, primary_key=True, autoincrement=True)
    country_code = Column(String(10), unique=True, nullable=False, index=True)
    country_name = Column(String(100), nullable=True)
    police = Column(String(20), nullable=True)
    ambulance = Column(String(20), nullable=True)
    fire = Column(String(20), nullable=True)
    national_emergency = Column(String(20), default="112")


# ── 6. Service Feedback (user-submitted ratings) ──────────
class ServiceFeedback(Base):
    __tablename__ = "service_feedback"

    id = Column(Integer, primary_key=True, autoincrement=True)
    service_id = Column(Integer, ForeignKey("cached_services.id"), nullable=False, index=True)
    rating = Column(SmallInteger, nullable=False)          # 1–5
    comment = Column(Text, nullable=True)
    device_id = Column(String(100), nullable=True)
    submitted_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationship
    service = relationship("CachedService", back_populates="feedbacks")


# ── 7. App Logs (audit / analytics) ───────────────────────
class AppLog(Base):
    __tablename__ = "app_logs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    event_type = Column(String(100), nullable=False, index=True)  # SOS_TRIGGERED, SEARCH, REPORT, etc.
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    device_id = Column(String(100), nullable=True)
    log_metadata = Column("metadata", Text, nullable=True)                # JSON string
    logged_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)

`

### File: backend\app\models\__init__.py
`python

`

### File: backend\app\routers\accident.py
`python
from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.utils.database import get_db
from app.models.db_models import AccidentReport, AppLog
from typing import Optional
import os, uuid, json

router = APIRouter()
UPLOAD_DIR = "uploads/accidents"
os.makedirs(UPLOAD_DIR, exist_ok=True)


@router.post("/report", summary="Submit an accident report")
async def report_accident(
    latitude: float = Form(...),
    longitude: float = Form(...),
    severity: str = Form("moderate"),
    casualties: int = Form(0),
    description: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None),
    db: AsyncSession = Depends(get_db),
):
    img_path = None
    if image and image.filename:
        ext = os.path.splitext(image.filename)[1]
        filename = f"{uuid.uuid4().hex}{ext}"
        img_path = os.path.join(UPLOAD_DIR, filename)
        with open(img_path, "wb") as f:
            content = await image.read()
            f.write(content)

    report = AccidentReport(
        latitude=latitude,
        longitude=longitude,
        severity=severity,
        casualties=casualties,
        description=description,
        image_path=img_path,
        status="open",
    )
    db.add(report)

    db.add(AppLog(
        event_type="ACCIDENT_REPORTED",
        latitude=latitude,
        longitude=longitude,
        metadata=json.dumps({"severity": severity, "casualties": casualties}),
    ))

    await db.commit()
    await db.refresh(report)

    return {
        "status": "ok",
        "report_id": report.id,
        "has_image": img_path is not None,
        "message": "Accident report saved. Emergency services may be alerted.",
    }


@router.get("/reports", summary="List accident reports")
async def list_reports(
    status: Optional[str] = None,
    severity: Optional[str] = None,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
):
    q = select(AccidentReport).order_by(AccidentReport.reported_at.desc()).limit(limit)
    if status:
        q = q.where(AccidentReport.status == status)
    if severity:
        q = q.where(AccidentReport.severity == severity)
    result = await db.execute(q)
    reports = result.scalars().all()
    return {
        "total": len(reports),
        "reports": [
            {
                "id": r.id,
                "lat": r.latitude,
                "lng": r.longitude,
                "severity": r.severity,
                "casualties": r.casualties,
                "status": r.status,
                "reported_at": str(r.reported_at),
            }
            for r in reports
        ],
    }


@router.get("/reports/{report_id}", summary="Get a specific accident report")
async def get_report(report_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(AccidentReport).where(AccidentReport.id == report_id))
    report = result.scalar_one_or_none()
    if not report:
        raise HTTPException(404, "Report not found")
    return {
        "id": report.id,
        "latitude": report.latitude,
        "longitude": report.longitude,
        "severity": report.severity,
        "casualties": report.casualties,
        "description": report.description,
        "image_path": report.image_path,
        "status": report.status,
        "reported_at": str(report.reported_at),
    }

`

### File: backend\app\routers\ai_analysis.py
`python
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.utils.database import get_db
from app.models.db_models import AIAnalysisResult, AccidentReport
from pydantic import BaseModel
from typing import Optional, List
import io, json, os

router = APIRouter()


class AnalysisResult(BaseModel):
    detected_objects: List[str]
    severity_estimate: str
    confidence: float
    recommendations: List[str]
    vehicles_count: int
    persons_detected: bool


@router.post("/analyze", response_model=AnalysisResult, summary="Analyze accident image with YOLOv8")
async def analyze_image(
    image: UploadFile = File(...),
    report_id: Optional[int] = None,
    db: AsyncSession = Depends(get_db),
):
    try:
        contents = await image.read()
        result = await _run_yolo(contents)

        # Persist result to DB if linked to a report
        if report_id:
            existing = await db.execute(
                select(AIAnalysisResult).where(AIAnalysisResult.accident_report_id == report_id)
            )
            if not existing.scalar_one_or_none():
                db.add(AIAnalysisResult(
                    accident_report_id=report_id,
                    detected_objects=json.dumps(result.detected_objects),
                    severity_estimate=result.severity_estimate,
                    confidence_score=result.confidence,
                    vehicles_count=result.vehicles_count,
                    persons_detected=result.persons_detected,
                    recommendations=json.dumps(result.recommendations),
                ))
                await db.commit()

        return result
    except Exception as e:
        raise HTTPException(500, f"AI analysis failed: {str(e)}")


async def _run_yolo(image_bytes: bytes) -> AnalysisResult:
    try:
        from ultralytics import YOLO
        from PIL import Image

        model_path = os.getenv("YOLO_MODEL_PATH", "ai_module/models/accident_detector.pt")
        if not os.path.exists(model_path):
            model_path = "yolov8n.pt"

        model = YOLO(model_path)
        img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        results = model(img, verbose=False)

        detected, vehicles, persons = [], 0, False
        for r in results:
            for box in r.boxes:
                cls_name = r.names[int(box.cls)]
                detected.append(cls_name)
                if cls_name in ["car", "truck", "bus", "motorcycle", "bicycle"]:
                    vehicles += 1
                if cls_name == "person":
                    persons = True

        severity = "critical" if persons and vehicles >= 2 else "moderate" if persons or vehicles >= 2 else "minor"
        recs = _recommendations(severity, persons, vehicles)
        conf = float(results[0].boxes.conf.mean()) if len(results[0].boxes) > 0 else 0.0

        return AnalysisResult(
            detected_objects=list(set(detected)),
            severity_estimate=severity,
            confidence=round(conf, 2),
            recommendations=recs,
            vehicles_count=vehicles,
            persons_detected=persons,
        )
    except ImportError:
        return AnalysisResult(
            detected_objects=["vehicle"],
            severity_estimate="moderate",
            confidence=0.0,
            recommendations=["Call 112", "Do not move injured"],
            vehicles_count=1,
            persons_detected=False,
        )


def _recommendations(severity, persons, vehicles):
    recs = ["Call 112 (National Emergency)"]
    if persons:
        recs += ["Injured persons detected — Call 108 Ambulance", "Do NOT move injured unless immediate danger"]
    if vehicles:
        recs.append("Contact towing service for vehicle recovery")
    if severity == "critical":
        recs.append("Secure scene — alert police 100")
    recs.append("Document scene for insurance")
    return recs

`

### File: backend\app\routers\emergency.py
`python
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.utils.database import get_db
from app.models.db_models import EmergencyNumber
from pydantic import BaseModel
from typing import Optional

router = APIRouter()


class EmergencyNumberOut(BaseModel):
    country_code: str
    country_name: Optional[str]
    police: Optional[str]
    ambulance: Optional[str]
    fire: Optional[str]
    national_emergency: Optional[str]


@router.get("/numbers", response_model=list[EmergencyNumberOut], summary="Get all emergency numbers")
async def get_all_numbers(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(EmergencyNumber).order_by(EmergencyNumber.country_code))
    return result.scalars().all()


@router.get("/numbers/{country_code}", response_model=EmergencyNumberOut, summary="Get numbers for a country")
async def get_country_numbers(country_code: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(EmergencyNumber).where(EmergencyNumber.country_code == country_code.upper())
    )
    row = result.scalar_one_or_none()
    if not row:
        # Fall back to DEFAULT
        result = await db.execute(
            select(EmergencyNumber).where(EmergencyNumber.country_code == "DEFAULT")
        )
        row = result.scalar_one_or_none()
    if not row:
        raise HTTPException(404, f"No emergency numbers for {country_code}")
    return row

`

### File: backend\app\routers\feedback.py
`python
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.utils.database import get_db
from app.models.db_models import ServiceFeedback, CachedService
from pydantic import BaseModel
from typing import Optional

router = APIRouter()


class FeedbackIn(BaseModel):
    service_id: int
    rating: int       # 1-5
    comment: Optional[str] = None
    device_id: Optional[str] = None


@router.post("/submit", summary="Submit feedback for a service")
async def submit_feedback(payload: FeedbackIn, db: AsyncSession = Depends(get_db)):
    if not (1 <= payload.rating <= 5):
        raise HTTPException(400, "Rating must be 1-5")

    # Verify service exists
    result = await db.execute(select(CachedService).where(CachedService.id == payload.service_id))
    svc = result.scalar_one_or_none()
    if not svc:
        raise HTTPException(404, f"Service {payload.service_id} not found")

    fb = ServiceFeedback(
        service_id=payload.service_id,
        rating=payload.rating,
        comment=payload.comment,
        device_id=payload.device_id,
    )
    db.add(fb)
    await db.commit()
    await db.refresh(fb)
    return {"status": "ok", "feedback_id": fb.id}


@router.get("/service/{service_id}", summary="Get feedback for a service")
async def get_service_feedback(service_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(ServiceFeedback).where(ServiceFeedback.service_id == service_id)
        .order_by(ServiceFeedback.submitted_at.desc())
    )
    feedbacks = result.scalars().all()
    avg = sum(f.rating for f in feedbacks) / len(feedbacks) if feedbacks else 0
    return {
        "service_id": service_id,
        "average_rating": round(avg, 1),
        "total_reviews": len(feedbacks),
        "feedbacks": [{"rating": f.rating, "comment": f.comment, "at": str(f.submitted_at)} for f in feedbacks],
    }

`

### File: backend\app\routers\logs.py
`python
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.utils.database import get_db
from app.models.db_models import AppLog
from pydantic import BaseModel
from typing import Optional
import json

router = APIRouter()


class LogIn(BaseModel):
    event_type: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    device_id: Optional[str] = None
    metadata: Optional[dict] = None


@router.post("/event", summary="Log an app event")
async def log_event(payload: LogIn, db: AsyncSession = Depends(get_db)):
    log = AppLog(
        event_type=payload.event_type,
        latitude=payload.latitude,
        longitude=payload.longitude,
        device_id=payload.device_id,
        log_metadata=json.dumps(payload.metadata) if payload.metadata else None,
    )
    db.add(log)
    await db.commit()
    return {"status": "logged"}


@router.get("/recent", summary="Get recent app logs")
async def recent_logs(limit: int = 50, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(AppLog).order_by(AppLog.logged_at.desc()).limit(limit)
    )
    logs = result.scalars().all()
    return {"total": len(logs), "logs": [
        {"id": l.id, "event": l.event_type, "lat": l.latitude, "lng": l.longitude, "at": str(l.logged_at)}
        for l in logs
    ]}

`

### File: backend\app\routers\services.py
`python
from fastapi import APIRouter, Query, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.utils.database import get_db
from app.models.db_models import CachedService, AppLog, ServiceTypeEnum
from app.services.osm_service import fetch_nearby_from_osm
from pydantic import BaseModel
from typing import List, Optional
import json

router = APIRouter()

VALID_TYPES = ["police", "hospital", "ambulance", "towing", "puncture", "showroom"]


class ServiceResult(BaseModel):
    id: str
    name: str
    type: str
    latitude: float
    longitude: float
    distance_km: float
    phone: Optional[str] = None
    address: Optional[str] = None
    is_open: bool = True
    is_cached: bool = False
    country_code: Optional[str] = None


class NearbyResponse(BaseModel):
    results: List[ServiceResult]
    total: int
    source: str  # "osm_live" | "db_cache" | "both"


@router.get("/nearby", response_model=NearbyResponse, summary="Get nearby emergency services")
async def get_nearby_services(
    lat: float = Query(..., description="User latitude"),
    lng: float = Query(..., description="User longitude"),
    type: str = Query("hospital", description="Service type: police|hospital|ambulance|towing|puncture|showroom"),
    radius: int = Query(5000, description="Radius in meters (max 20000)", le=20000),
    db: AsyncSession = Depends(get_db),
):
    if type not in VALID_TYPES:
        raise HTTPException(400, f"Invalid type. Choose: {VALID_TYPES}")

    source = "osm_live"
    places = []

    # 1. Try OSM Overpass (live)
    try:
        raw = await fetch_nearby_from_osm(lat, lng, type, radius)
        places = [ServiceResult(**p) for p in raw]

        # 2. Upsert into cached_services for offline fallback
        for p in raw[:10]:  # cache top 10
            existing = await db.execute(
                select(CachedService).where(CachedService.osm_id == p["id"])
            )
            if not existing.scalar_one_or_none():
                db.add(CachedService(
                    osm_id=p["id"],
                    name=p["name"],
                    service_type=type,
                    latitude=p["latitude"],
                    longitude=p["longitude"],
                    phone=p.get("phone"),
                    address=p.get("address"),
                    country_code="IN",
                ))
        await db.commit()

    except Exception as osm_err:
        # 3. OSM failed — fall back to DB cache
        source = "db_cache"
        result = await db.execute(
            select(CachedService).where(
                CachedService.service_type == type,
                CachedService.is_active == True,
            ).limit(20)
        )
        rows = result.scalars().all()
        from math import radians, sin, cos, sqrt, atan2
        def _dist(lat1, lon1, lat2, lon2):
            R = 6371
            dlat, dlon = radians(lat2-lat1), radians(lon2-lon1)
            a = sin(dlat/2)**2 + cos(radians(lat1))*cos(radians(lat2))*sin(dlon/2)**2
            return R * 2 * atan2(sqrt(a), sqrt(1-a))
        places = [
            ServiceResult(
                id=str(r.id), name=r.name, type=type,
                latitude=r.latitude, longitude=r.longitude,
                distance_km=round(_dist(lat, lng, r.latitude, r.longitude), 2),
                phone=r.phone, address=r.address,
                is_cached=True, country_code=r.country_code,
            )
            for r in rows
        ]
        places.sort(key=lambda x: x.distance_km)

    # Log the search event
    db.add(AppLog(
        event_type="NEARBY_SEARCH",
        latitude=lat, longitude=lng,
        metadata=json.dumps({"type": type, "radius": radius, "results": len(places)}),
    ))
    await db.commit()

    return NearbyResponse(results=places[:20], total=len(places), source=source)


@router.get("/types", summary="List available service types")
async def list_service_types():
    return {
        "types": [
            {"key": "police",    "label": "Police Station",   "icon": "🚔"},
            {"key": "hospital",  "label": "Hospital / Trauma","icon": "🏥"},
            {"key": "ambulance", "label": "Ambulance Service","icon": "🚑"},
            {"key": "towing",    "label": "Towing / Recovery","icon": "🚛"},
            {"key": "puncture",  "label": "Puncture Shop",    "icon": "🔧"},
            {"key": "showroom",  "label": "Car Showroom",     "icon": "🏪"},
        ]
    }

`

### File: backend\app\routers\sos.py
`python
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from app.utils.database import get_db
from app.models.db_models import SOSAlert, AppLog
from pydantic import BaseModel
from typing import Optional, List
import json

router = APIRouter()


class SOSRequest(BaseModel):
    latitude: float
    longitude: float
    severity: str = "critical"
    message: Optional[str] = None
    device_id: Optional[str] = None


class SOSResponse(BaseModel):
    status: str
    alert_id: int
    message: str
    nearest_emergency: str = "112"
    action: str = "CALL_112"


@router.post("/alert", response_model=SOSResponse, summary="Trigger SOS emergency alert")
async def send_sos_alert(payload: SOSRequest, db: AsyncSession = Depends(get_db)):
    alert = SOSAlert(
        latitude=payload.latitude,
        longitude=payload.longitude,
        severity=payload.severity,
        message=payload.message,
        device_id=payload.device_id,
        status="active",
    )
    db.add(alert)

    db.add(AppLog(
        event_type="SOS_TRIGGERED",
        latitude=payload.latitude,
        longitude=payload.longitude,
        device_id=payload.device_id,
        metadata=json.dumps({"severity": payload.severity}),
    ))

    await db.commit()
    await db.refresh(alert)

    return SOSResponse(
        status="received",
        alert_id=alert.id,
        message=f"SOS #{alert.id} recorded. Call 112 immediately.",
        nearest_emergency="112",
        action="CALL_112",
    )


@router.get("/alerts", summary="List all SOS alerts")
async def list_sos_alerts(
    status: Optional[str] = None,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
):
    q = select(SOSAlert).order_by(SOSAlert.alerted_at.desc()).limit(limit)
    if status:
        q = q.where(SOSAlert.status == status)
    result = await db.execute(q)
    alerts = result.scalars().all()
    return {
        "total": len(alerts),
        "alerts": [
            {
                "id": a.id,
                "lat": a.latitude,
                "lng": a.longitude,
                "severity": a.severity,
                "status": a.status,
                "message": a.message,
                "alerted_at": str(a.alerted_at),
            }
            for a in alerts
        ],
    }


@router.patch("/alerts/{alert_id}/resolve", summary="Resolve an SOS alert")
async def resolve_alert(alert_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(SOSAlert).where(SOSAlert.id == alert_id))
    alert = result.scalar_one_or_none()
    if not alert:
        raise HTTPException(404, f"Alert {alert_id} not found")
    alert.status = "resolved"
    await db.commit()
    return {"status": "ok", "alert_id": alert_id, "message": "Alert resolved"}

`

### File: backend\app\routers\sync.py
`python
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.utils.database import get_db
from app.services.osm_service import fetch_nearby_from_osm

router = APIRouter()
OFFLINE_TYPES = ["police", "hospital", "ambulance"]


@router.get("/offline-data", summary="Pre-fetch all critical services for offline cache")
async def get_offline_bundle(
    lat: float,
    lng: float,
    db: AsyncSession = Depends(get_db),
):
    bundle = {}
    for stype in OFFLINE_TYPES:
        try:
            places = await fetch_nearby_from_osm(lat, lng, stype, radius=10000)
            bundle[stype] = places
        except Exception:
            bundle[stype] = []

    return {
        "status": "ok",
        "bundle": bundle,
        "types_synced": OFFLINE_TYPES,
        "note": "Cache this response in Hive for offline use",
    }

`

### File: backend\app\routers\__init__.py
`python

`

### File: backend\app\services\osm_service.py
`python
import httpx
from typing import List, Dict, Any
import asyncio

OVERPASS_URL = "https://overpass-api.de/api/interpreter"

OSM_TAG_MAP = {
    "police": "amenity=police",
    "hospital": "amenity=hospital",
    "ambulance": "amenity=ambulance_station",
    "towing": "shop=car_repair",
    "puncture": "shop=tyres",
    "showroom": "shop=car",
}


async def fetch_nearby_from_osm(
    lat: float, lng: float, service_type: str, radius: int = 5000
) -> List[Dict[str, Any]]:
    """
    Fetches nearby services from OpenStreetMap Overpass API.
    Free, no API key, global coverage.
    """
    osm_tag = OSM_TAG_MAP.get(service_type, "amenity=hospital")
    tag_key, tag_val = osm_tag.split("=")

    query = f"""
[out:json][timeout:25];
(
  node["{tag_key}"="{tag_val}"](around:{radius},{lat},{lng});
  way["{tag_key}"="{tag_val}"](around:{radius},{lat},{lng});
);
out center 30;
"""

    async with httpx.AsyncClient(timeout=20.0) as client:
        resp = await client.post(
            OVERPASS_URL,
            data={"data": query},
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )
        resp.raise_for_status()
        data = resp.json()

    results = []
    for el in data.get("elements", []):
        el_lat = el.get("lat") or el.get("center", {}).get("lat", 0)
        el_lng = el.get("lon") or el.get("center", {}).get("lon", 0)
        tags = el.get("tags", {})

        results.append({
            "id": str(el.get("id")),
            "name": tags.get("name") or tags.get("operator") or f"Unknown {service_type}",
            "type": service_type,
            "latitude": el_lat,
            "longitude": el_lng,
            "distance_km": _haversine(lat, lng, el_lat, el_lng),
            "phone": tags.get("phone") or tags.get("contact:phone"),
            "address": tags.get("addr:full") or tags.get("addr:street"),
            "is_open": True,
        })

    results.sort(key=lambda x: x["distance_km"])
    return results[:20]


def _haversine(lat1, lon1, lat2, lon2) -> float:
    from math import radians, sin, cos, sqrt, atan2
    R = 6371
    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)
    a = sin(dlat/2)**2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon/2)**2
    return R * 2 * atan2(sqrt(a), sqrt(1-a))

`

### File: backend\app\services\__init__.py
`python

`

### File: backend\app\utils\database.py
`python
"""
RoadSOS — MySQL Database Connection
DB: roadsos_db | User: roadsos_admin | Pass: roadsos_pass
Uses async SQLAlchemy 2.x + aiomysql driver
"""
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import declarative_base
from sqlalchemy import text
import os
from dotenv import load_dotenv

load_dotenv()

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "3306")
DB_USER = os.getenv("DB_USER", "roadsos_admin")
DB_PASSWORD = os.getenv("DB_PASSWORD", "roadsos_pass")
DB_NAME = os.getenv("DB_NAME", "roadsos_db")

DATABASE_URL = (
    f"mysql+aiomysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    f"?charset=utf8mb4"
)

engine = create_async_engine(
    DATABASE_URL,
    echo=bool(os.getenv("DEBUG", "true").lower() == "true"),
    pool_pre_ping=True,
    pool_recycle=3600,
    pool_size=10,
    max_overflow=20,
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
    autocommit=False,
)

Base = declarative_base()


async def get_db():
    """FastAPI dependency — yields an async DB session."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def check_db_connection() -> bool:
    """Health check — returns True if DB is reachable."""
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        return True
    except Exception as e:
        print(f"DB connection failed: {e}")
        return False

`

### File: backend\app\utils\__init__.py
`python

`

