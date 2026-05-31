import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_theme.dart';
import '../features/emergency/sos_confirm_sheet.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

class SOSButton extends StatefulWidget {
  const SOSButton({super.key});

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isActivated = false;
  int? _activeAlertId;

  // Cancel countdown state
  bool _showCancelBanner = false;
  int _cancelSecondsLeft = 10;
  Timer? _cancelTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cancelTimer?.cancel();
    super.dispose();
  }

  void _showConfirmSheet() {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SosConfirmSheet(onConfirm: _triggerSOS),
    );
  }

  Future<void> _triggerSOS() async {
    HapticFeedback.heavyImpact();
    final loc = context.read<LocationService>();
    final api = context.read<ApiService>();

    if (!loc.hasPermission || loc.currentPosition == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission required for SOS.'), backgroundColor: AppTheme.primaryRed),
        );
      }
      return;
    }

    setState(() => _isActivated = true);

    // Check for internet connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      // User is completely offline. Trigger SMS fallback.
      await _triggerOfflineSMS(loc.currentPosition!.latitude, loc.currentPosition!.longitude);
      return;
    }

    final result = await api.sendSOSAlert(
      latitude: loc.currentPosition!.latitude,
      longitude: loc.currentPosition!.longitude,
      severity: 'critical',
      message: 'Emergency SOS triggered',
    );

    if (!mounted) return;

    if (result['status'] != 'error') {
      final alertId = result['alert_id'];
      _activeAlertId = alertId is int ? alertId : int.tryParse(alertId.toString());
      _startCancelCountdown();
    } else {
      setState(() => _isActivated = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Failed to send SOS'), backgroundColor: AppTheme.primaryRed),
      );
    }
  }

  Future<void> _triggerOfflineSMS(double lat, double lng) async {
    final message = "EMERGENCY SOS: I need immediate assistance at my location: https://www.google.com/maps/search/?api=1&query=$lat,$lng";
    final uri = Uri.parse("sms:100?body=${Uri.encodeComponent(message)}");

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      if (mounted) {
        setState(() => _isActivated = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offline Mode: Opened SMS App to send SOS.'),
            backgroundColor: AppTheme.accentGreen,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } else {
      if (mounted) {
        setState(() => _isActivated = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open SMS app. Please text 100 manually.'),
            backgroundColor: AppTheme.primaryRed,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _startCancelCountdown() {
    setState(() {
      _showCancelBanner = true;
      _cancelSecondsLeft = 10;
    });

    _cancelTimer?.cancel();
    _cancelTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _cancelSecondsLeft--);
      if (_cancelSecondsLeft <= 0) {
        t.cancel();
        _confirmAlertFinal();
      }
    });
  }

  void _confirmAlertFinal() {
    if (!mounted) return;
    setState(() {
      _showCancelBanner = false;
      _isActivated = false;
    });
    _showDispatchConfirmedSnack();
  }

  Future<void> _cancelAlert() async {
    _cancelTimer?.cancel();
    final api = context.read<ApiService>();

    if (_activeAlertId != null) {
      await api.cancelSosAlert(_activeAlertId!);
    }

    if (!mounted) return;
    setState(() {
      _showCancelBanner = false;
      _isActivated = false;
      _activeAlertId = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ SOS cancelled. Officers have been stood down.'),
        backgroundColor: AppTheme.accentGreen,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showDispatchConfirmedSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🚨 Alert #$_activeAlertId confirmed — Officer dispatched to your location.'),
        backgroundColor: AppTheme.primaryRed,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onLongPress: _isActivated ? null : _showConfirmSheet,
          child: Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (_isActivated ? AppTheme.accentGreen : AppTheme.primaryRed).withOpacity(0.25),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale1 = 1.0 + (_pulseController.value * 0.15);
                final scale2 = 1.0 + (_pulseController.value * 0.30);

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!_isActivated) ...[
                      Transform.scale(scale: scale2, child: Container(width: 110, height: 110, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryRed.withOpacity(0.05)))),
                      Transform.scale(scale: scale1, child: Container(width: 110, height: 110, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryRed.withOpacity(0.1)))),
                    ],
                    Transform.scale(
                      scale: _isActivated ? 1.0 : 1.0 + (_pulseController.value * 0.04),
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _isActivated
                                ? [AppTheme.accentGreen, const Color(0xFF28A745)]
                                : [AppTheme.primaryRed, const Color(0xFFC0392B)],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _isActivated ? 'SENT' : 'SOS',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      child: Text(
                        _isActivated ? 'Officers notified. Stay calm.' : 'Hold to activate',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        // 10-second cancel countdown banner
        if (_showCancelBanner)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A0A00),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.accentAmber.withOpacity(0.6)),
            ),
            child: Row(
              children: [
                // Countdown circle
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _cancelSecondsLeft / 10.0,
                        color: AppTheme.accentAmber,
                        backgroundColor: AppTheme.accentAmber.withOpacity(0.2),
                        strokeWidth: 3,
                      ),
                      Text(
                        '$_cancelSecondsLeft',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.accentAmber),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Alert Sent!', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text('Tap Cancel if this was a mistake.', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _cancelAlert,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentAmber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accentAmber.withOpacity(0.5)),
                    ),
                    child: const Text('CANCEL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.accentAmber)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
