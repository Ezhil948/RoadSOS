import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'services/api_service.dart';
import 'services/location_service.dart';
import 'services/offline_sync_service.dart';
import 'services/auth_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/phone_verify_screen.dart';

bool _firebaseInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    _firebaseInitialized = true;
  } catch (e) {
    debugPrint('Firebase init failed on web: $e');
  }
  runApp(const RoadSOSApp());
}

class RoadSOSApp extends StatelessWidget {
  const RoadSOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ApiService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
        ChangeNotifierProvider(
          create: (context) => OfflineSyncService(
            apiService: context.read<ApiService>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'RoadSOS',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        darkTheme: AppTheme.darkTheme,
        home: _firebaseInitialized && FirebaseAuth.instance.currentUser == null
            ? const PhoneVerifyScreen()
            : const SplashScreen(),
      ),
    );
  }
}
