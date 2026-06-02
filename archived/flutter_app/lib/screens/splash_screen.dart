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
