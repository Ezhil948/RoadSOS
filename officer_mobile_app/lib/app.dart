import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

// Import screens
import 'features/auth/splash_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/history/history_screen.dart';
import 'features/dispatch/resolution_screen.dart';
import 'features/dispatch/dispatch_provider.dart';

import 'features/map/main_map_screen.dart';
import 'widgets/global_dispatch_overlay.dart';

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

// removed cleanDispatchProvider

final networkStatusProvider = Provider<Color>((ref) {
  final connectivity = ref.watch(connectivityProvider).value;
  final dispatchState = ref.watch(dispatchProvider);
  
  if (connectivity == null || connectivity.contains(ConnectivityResult.none)) {
    return kAccentRed; // red when no network
  }
  
  if (dispatchState is Offline) {
    return kAccentAmber; // amber when offline/disconnected
  }
  
  return kAccentGreen; // green when connected + online
});

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      GoRoute(
        path: '/dispatch/resolve',
        builder: (context, state) => const ResolutionScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return Stack(
            children: [
              Scaffold(
                body: navigationShell,
                bottomNavigationBar: BottomNavigationBar(
                  currentIndex: navigationShell.currentIndex,
                  onTap: (index) => navigationShell.goBranch(
                    index,
                    initialLocation: index == navigationShell.currentIndex,
                  ),
                  items: const [
                    BottomNavigationBarItem(icon: Icon(Icons.shield_outlined), label: 'Duty'),
                    BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Map'),
                    BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
                    BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Calendar'),
                    BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
                  ],
                ),
              ),
              const GlobalDispatchOverlay(),
            ],
          );
        },
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/map',
              builder: (context, state) => const MainMapScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/calendar',
              builder: (context, state) => const CalendarScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});

class RoadSOSApp extends ConsumerWidget {
  const RoadSOSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'RoadSOS Officer',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
