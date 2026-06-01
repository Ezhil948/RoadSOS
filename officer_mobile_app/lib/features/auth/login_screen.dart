import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _badgeController = TextEditingController(text: '4821');
  final _passController = TextEditingController(text: 'password');
  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _logoController;
  late AnimationController _cardController;
  late AnimationController _orbController;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _cardFade;
  late Animation<double> _orbRotation;

  @override
  void initState() {
    super.initState();

    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _orbRotation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _orbController, curve: Curves.linear),
    );

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic),
    );
    _cardFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeIn),
    );

    // Stagger animations
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _logoController.forward();
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _cardController.forward();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _cardController.dispose();
    _orbController.dispose();
    _badgeController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _login() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'badge_number': _badgeController.text.trim(),
          'password': _passController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final box = Hive.box('settings');
        await box.put('officer_id', data['officer_id']);
        await box.put('badge_number', data['badge_number']);
        await box.put('officer_name', data['name']);
        
        if (mounted) {
          context.go('/');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid badge or password')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Deep gradient background ────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF020817), // near black
                  Color(0xFF0F172A), // slate 900
                  Color(0xFF0C1445), // deep navy
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ── Animated decorative orbs ────────────────────────────────────
          AnimatedBuilder(
            animation: _orbRotation,
            builder: (context, _) {
              return Stack(
                children: [
                  // Top-left large orb
                  Positioned(
                    top: -100 + 30 * math.sin(_orbRotation.value),
                    left: -80 + 20 * math.cos(_orbRotation.value),
                    child: _Orb(size: 300, color: const Color(0xFF1E40AF).withOpacity(0.18)),
                  ),
                  // Bottom-right orb
                  Positioned(
                    bottom: -120 + 25 * math.cos(_orbRotation.value),
                    right: -60 + 20 * math.sin(_orbRotation.value),
                    child: _Orb(size: 280, color: const Color(0xFF3B82F6).withOpacity(0.12)),
                  ),
                  // Mid accent orb (amber)
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.35 + 20 * math.sin(_orbRotation.value * 0.7),
                    right: -40,
                    child: _Orb(size: 160, color: const Color(0xFFF59E0B).withOpacity(0.08)),
                  ),
                ],
              );
            },
          ),

          // ── Grid pattern overlay ────────────────────────────────────────
          Positioned.fill(
            child: CustomPaint(painter: _GridPainter()),
          ),

          // ── Main content ────────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Logo section ──────────────────────────────────────
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: Column(
                          children: [
                            // Badge emblem
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF1D4ED8), Color(0xFF1E40AF)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF3B82F6).withOpacity(0.45),
                                    blurRadius: 30,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Icon(
                                    Icons.shield_rounded,
                                    size: 68,
                                    color: Color(0xFF93C5FD),
                                  ),
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 24,
                                    color: Color(0xFFFBBF24),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Main Branding text
                            const Text(
                              'ROADSOS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.6)),
                                borderRadius: BorderRadius.circular(20),
                                color: const Color(0xFFF59E0B).withOpacity(0.08),
                              ),
                              child: const Text(
                                'OFFICER PORTAL',
                                style: TextStyle(
                                  color: Color(0xFFFBBF24),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // ── Glassmorphism login card ───────────────────────────
                    FadeTransition(
                      opacity: _cardFade,
                      child: SlideTransition(
                        position: _cardSlide,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: const Color(0xFF1E293B).withOpacity(0.7),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 40,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Card header
                                Row(
                                  children: [
                                    Container(
                                      width: 3,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3B82F6),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'Secure Sign In',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.only(left: 13),
                                  child: Text(
                                    'Enter your credentials to continue',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.45),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 28),

                                // Badge number field
                                _FieldLabel(label: 'Badge Number'),
                                const SizedBox(height: 8),
                                _LoginField(
                                  controller: _badgeController,
                                  hint: 'Enter badge number',
                                  icon: Icons.badge_rounded,
                                  keyboardType: TextInputType.text,
                                ),

                                const SizedBox(height: 20),

                                // Password field
                                _FieldLabel(label: 'Password'),
                                const SizedBox(height: 8),
                                _LoginField(
                                  controller: _passController,
                                  hint: 'Enter password',
                                  icon: Icons.lock_rounded,
                                  obscure: _obscurePassword,
                                  suffixIcon: GestureDetector(
                                    onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                                    child: Icon(
                                      _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                      color: Colors.white.withOpacity(0.4),
                                      size: 20,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // Forgot password
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      color: const Color(0xFF60A5FA).withOpacity(0.8),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 28),

                                // Login button
                                GestureDetector(
                                  onTap: _isLoading ? null : _login,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    height: 54,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: LinearGradient(
                                        colors: _isLoading
                                            ? [const Color(0xFF1D4ED8).withOpacity(0.5), const Color(0xFF1E40AF).withOpacity(0.5)]
                                            : [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
                                      ),
                                      boxShadow: _isLoading
                                          ? []
                                          : [
                                              BoxShadow(
                                                color: const Color(0xFF3B82F6).withOpacity(0.4),
                                                blurRadius: 16,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                    ),
                                    child: Center(
                                      child: _isLoading
                                          ? Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  'Authenticating...',
                                                  style: TextStyle(
                                                    color: Colors.white.withOpacity(0.8),
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: const [
                                                Icon(Icons.lock_open_rounded, color: Colors.white, size: 18),
                                                SizedBox(width: 10),
                                                Text(
                                                  'SIGN IN',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                    letterSpacing: 1.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Footer ─────────────────────────────────────────────
                    FadeTransition(
                      opacity: _cardFade,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.verified_user_rounded, size: 12, color: Colors.white.withOpacity(0.3)),
                              const SizedBox(width: 6),
                              Text(
                                'Secure · Encrypted · Monitored',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'RoadSOS v4.2.0 · Emergency Dispatch Platform',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.18),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: Colors.white.withOpacity(0.55),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;

  const _LoginField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.35), size: 20),
          suffixIcon: suffixIcon != null
              ? Padding(padding: const EdgeInsets.only(right: 12), child: suffixIcon)
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

// ── Subtle grid background painter ───────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 0.5;

    const spacing = 40.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
