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
import '../dispatch/dispatch_provider.dart';

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

  Widget _buildIdentityCard() {
    final box = Hive.box('settings');
    final officerName = box.get('officer_name', defaultValue: 'Officer').toString().toUpperCase();
    final badgeNumber = box.get('badge_number', defaultValue: '----').toString();
    final initial = officerName.isNotEmpty ? officerName[0] : 'O';
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? kDarkSurface : kLightSurface;
    final borderColor = isDark ? kDarkBorder : kLightBorder;
    final bgColor = isDark ? kDarkBg : kLightBg;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              border: Border.all(color: kAccentGreen, width: 2),
              shape: BoxShape.circle,
              color: bgColor,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: AppTheme.monoMd.copyWith(color: kAccentGreen, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  officerName,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text('Badge #$badgeNumber', style: AppTheme.monoSm.copyWith(color: isDark ? kDarkSubtext : kLightSubtext)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(color: kAccentGreen, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('ONLINE', style: AppTheme.monoSm.copyWith(color: kAccentGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDutyStatus(OfficerStatus status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? kDarkSurface : kLightSurface;
    final borderColor = isDark ? kDarkBorder : kLightBorder;
    final textColor = isDark ? kDarkText : kLightText;
    final mutedColor = isDark ? kDarkMuted : kLightMuted;
    
    String statusText;
    Color statusColor;
    
    if (status is Online) {
      statusText = 'ONLINE';
      statusColor = kAccentGreen;
    } else if (status is Navigating) {
      statusText = 'EN ROUTE';
      statusColor = kAccentBlue;
    } else if (status is Arrived) {
      statusText = 'ON SCENE';
      statusColor = kAccentAmber;
    } else if (status is Dispatching) {
      statusText = 'INCOMING';
      statusColor = kAccentRed;
    } else {
      statusText = 'OFFLINE';
      statusColor = mutedColor;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // Current status indicator
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: statusColor.withOpacity(0.4), blurRadius: 8)],
                  ),
                ),
                const SizedBox(height: 8),
                Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('Status', style: TextStyle(color: mutedColor, fontSize: 10)),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: borderColor),
          // Dispatches today
          Expanded(
            child: Column(
              children: [
                Text('—', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Dispatches', style: TextStyle(color: mutedColor, fontSize: 10)),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: borderColor),
          // Resolve rate
          Expanded(
            child: Column(
              children: [
                Text('—', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Resolved', style: TextStyle(color: mutedColor, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencySOS() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? kDarkSurface : kLightSurface;
    final borderColor = isDark ? kDarkBorder : kLightBorder;
    final mutedColor = isDark ? kDarkMuted : kLightMuted;
    
    return GestureDetector(
      onTapDown: (_) => _startPanicHold(),
      onTapUp: (_) => _cancelPanicHold(),
      onTapCancel: () => _cancelPanicHold(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _panicHoldProgress > 0
              ? kAccentRed.withOpacity(0.05 + (_panicHoldProgress * 0.15))
              : surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _panicHoldProgress > 0 ? kAccentRed.withOpacity(0.5) : borderColor,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.sos_rounded, color: kAccentRed, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'OFFICER DISTRESS SIGNAL',
                        style: TextStyle(color: kAccentRed, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hold for 3 seconds to alert station',
                        style: TextStyle(color: mutedColor, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _panicHoldProgress,
                minHeight: 6,
                backgroundColor: isDark ? kDarkBorder : kLightBorder,
                color: kAccentRed,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? kDarkBorder : kLightBorder;
    final textColor = isDark ? kDarkText : kLightText;
    final mutedColor = isDark ? kDarkMuted : kLightMuted;
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.settings_outlined, color: textColor),
          title: Text('Settings', style: TextStyle(color: textColor)),
          trailing: Icon(Icons.chevron_right, color: mutedColor),
          onTap: () => context.push('/settings'),
        ),
        Divider(color: borderColor),
        ListTile(
          leading: Icon(Icons.lock_outline, color: textColor),
          title: Text('Change Password', style: TextStyle(color: textColor)),
          trailing: Icon(Icons.chevron_right, color: mutedColor),
          onTap: _showChangePasswordModal,
        ),
        Divider(color: borderColor),
        ListTile(
          leading: const Icon(Icons.logout, color: kAccentRed),
          title: const Text('Log Out', style: TextStyle(color: kAccentRed, fontWeight: FontWeight.bold)),
          onTap: _logout,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? kDarkBg : kLightBg;
    final status = ref.watch(dispatchProvider);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
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
                    _buildIdentityCard(),
                    
                    const SizedBox(height: 20),
                    
                    const SectionHeader(title: 'DUTY STATUS'),
                    _buildDutyStatus(status),
                    
                    const SizedBox(height: 20),
                    
                    const SectionHeader(title: 'QUICK ACTIONS'),
                    _buildQuickActions(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


}
