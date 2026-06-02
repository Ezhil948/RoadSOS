import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'services/location_service.dart';
import 'services/api_service.dart';
import 'services/offline_service.dart';
import 'utils/app_theme.dart';

bool _firebaseInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    _firebaseInitialized = true;
  } catch (e) {
    debugPrint('Firebase initialization failed (likely missing web config): $e');
  }
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
        home: _firebaseInitialized && FirebaseAuth.instance.currentUser == null 
            ? const LoginScreen() 
            : const SplashScreen(),
      ),
    );
  }
}
