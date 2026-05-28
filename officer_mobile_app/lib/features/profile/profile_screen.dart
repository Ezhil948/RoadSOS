import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../widgets/components.dart';
import '../../widgets/stat_row.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with SingleTickerProviderStateMixin {
  bool _panicActive = false;
  double _panicHoldProgress = 0.0;
  Timer? _panicHoldTimer;
  late AnimationController _pulseController;
  final int _panicHoldTargetMs = 3000; // 3 seconds
  int _elapsedMs = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _panicHoldTimer?.cancel();
    super.dispose();
  }

  void _startPanicHold() {
    _elapsedMs = 0;
    _panicHoldTimer?.cancel();
    _panicHoldTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _elapsedMs += 100;
      if (mounted) {
        setState(() {
          _panicHoldProgress = (_elapsedMs / _panicHoldTargetMs).clamp(0.0, 1.0);
        });
      }
      
      if (_elapsedMs >= _panicHoldTargetMs) {
        timer.cancel();
        _triggerPanicAlert();
      }
    });
  }

  void _cancelPanicHold() {
    _panicHoldTimer?.cancel();
    _panicHoldTimer = null;
    if (mounted) {
      setState(() {
        _panicHoldProgress = 0.0;
      });
    }
  }

  void _triggerPanicAlert() async {
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact();

    setState(() {
      _panicActive = true;
      _panicHoldProgress = 0.0;
    });

    _pulseController.repeat(reverse: true);

    // Call API
    try {
      final dio = ref.read(dioProvider);
      await dio.post(ApiEndpoints.triggerSos(1));
    } catch (_) {}
  }

  void _acknowledgePanic() {
    _pulseController.stop();
    setState(() {
      _panicActive = false;
    });
  }

  void _logout() async {
    final box = Hive.box('settings');
    await box.delete('access_token');
    if (mounted) {
      context.go('/login');
    }
  }

  void _showChangePasswordModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? kDarkSurface : kLightSurface,
          title: Text('// CHANGE PASSWORD', style: AppTheme.monoMd.copyWith(color: kAccentGreen)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                obscureText: true,
                style: AppTheme.monoSm,
                decoration: InputDecoration(
                  labelText: 'CURRENT PASSWORD',
                  labelStyle: AppTheme.monoSm.copyWith(color: isDark ? kDarkMuted : kLightMuted),
                  filled: true,
                  fillColor: isDark ? kDarkBg : kLightBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                obscureText: true,
                style: AppTheme.monoSm,
                decoration: InputDecoration(
                  labelText: 'NEW PASSWORD',
                  labelStyle: AppTheme.monoSm.copyWith(color: isDark ? kDarkMuted : kLightMuted),
                  filled: true,
                  fillColor: isDark ? kDarkBg : kLightBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password updated successfully'), backgroundColor: kAccentGreen),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: kAccentGreen),
              child: const Text('UPDATE', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bgColor = isDark ? kDarkBg : kLightBg;
    final surfaceColor = isDark ? kDarkSurface : kLightSurface;
    final borderColor = isDark ? kDarkBorder : kLightBorder;
    final textColor = isDark ? kDarkText : kLightText;
    final subtextColor = isDark ? kDarkSubtext : kLightSubtext;
    final mutedColor = isDark ? kDarkMuted : kLightMuted;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Panic SOS banner
            if (_panicActive)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: double.infinity,
                    color: kAccentRed.withOpacity(0.3 + (_pulseController.value * 0.7)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'PANIC ALERT IN PROGRESS — STATION NOTIFIED',
                              style: AppTheme.monoSm.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: _acknowledgePanic,
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                          child: const Text('DISMISS', style: TextStyle(color: kAccentRed, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
              ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'OFFICER PROFILE'),

                    // Header Card with Long Press Hexagon Avatar
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTapDown: (_) => _startPanicHold(),
                            onTapUp: (_) => _cancelPanicHold(),
                            onTapCancel: () => _cancelPanicHold(),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Circular progress surrounding avatar
                                SizedBox(
                                  width: 68,
                                  height: 68,
                                  child: CircularProgressIndicator(
                                    value: _panicHoldProgress,
                                    color: kAccentRed,
                                    backgroundColor: Colors.transparent,
                                    strokeWidth: 4,
                                  ),
                                ),
                                // Hexagon Monogram RS
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _panicHoldProgress > 0 ? kAccentRed : kAccentGreen,
                                      width: 2,
                                    ),
                                    shape: BoxShape.circle,
                                    color: bgColor,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'RS',
                                    style: AppTheme.monoMd.copyWith(
                                      color: _panicHoldProgress > 0 ? kAccentRed : kAccentGreen,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SGT. RAJAN KUMAR',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Badge #4821 · Chennai Central',
                                  style: AppTheme.monoSm.copyWith(color: subtextColor),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Joined: March 2021',
                                  style: AppTheme.monoSm.copyWith(color: mutedColor, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        '(Hold avatar for 3s to trigger distress SOS)',
                        style: AppTheme.monoSm.copyWith(color: mutedColor, fontSize: 10),
                      ),
                    ),
                    const SizedBox(height: 24),

                    const SectionHeader(title: 'CAREER STATS'),
                    StatRow(icon: Icons.assignment_outlined, label: 'Total dispatches', value: '847'),
                    StatRow(icon: Icons.speed, label: 'Avg response time', value: '5m 14s'),
                    StatRow(icon: Icons.done_all, label: 'Resolution rate', value: '94.2%'),
                    StatRow(icon: Icons.star_border, label: 'Current rating', value: '4.92 ★'),
                    StatRow(icon: Icons.report_problem_outlined, label: 'False alarm flags', value: '3'),
                    
                    const SizedBox(height: 32),
                    const SectionHeader(title: '7-DAY SHIFT HISTORY (Dispatches)'),

                    // Chart
                    Container(
                      height: 160,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: 8,
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (val, meta) {
                                  final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                                  if (val >= 0 && val < 7) {
                                    return Text(days[val.toInt()], style: AppTheme.monoSm.copyWith(color: subtextColor, fontSize: 10));
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          barGroups: [
                            _buildBarGroup(0, 3, isDark),
                            _buildBarGroup(1, 5, isDark),
                            _buildBarGroup(2, 4, isDark),
                            _buildBarGroup(3, 2, isDark),
                            _buildBarGroup(4, 6, isDark),
                            _buildBarGroup(5, 1, isDark),
                            _buildBarGroup(6, 4, isDark),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                    const SectionHeader(title: 'QUICK ACTIONS'),

                    // Settings Link
                    ListTile(
                      leading: Icon(Icons.settings_outlined, color: textColor),
                      title: Text('Settings', style: TextStyle(color: textColor)),
                      trailing: Icon(Icons.chevron_right, color: mutedColor),
                      onTap: () => context.push('/settings'),
                    ),
                    Divider(color: borderColor),

                    // Password change
                    ListTile(
                      leading: Icon(Icons.lock_outline, color: textColor),
                      title: Text('Change Password', style: TextStyle(color: textColor)),
                      trailing: Icon(Icons.chevron_right, color: mutedColor),
                      onTap: _showChangePasswordModal,
                    ),
                    Divider(color: borderColor),

                    // Log out
                    ListTile(
                      leading: const Icon(Icons.logout, color: kAccentRed),
                      title: const Text('Log Out', style: TextStyle(color: kAccentRed, fontWeight: FontWeight.bold)),
                      onTap: _logout,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y, bool isDark) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: kAccentGreen,
          width: 14,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 8,
            color: isDark ? kDarkSurface : kLightSurface,
          ),
        ),
      ],
    );
  }
}
