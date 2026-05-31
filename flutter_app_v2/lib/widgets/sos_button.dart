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

import '../features/emergency/reactivation_dialog.dart';
import 'package:hive/hive.dart';

class SOSButton extends StatefulWidget {
  const SOSButton({super.key});

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isActivated = false;
  int? _activeAlertId;

  // Polling state
  Timer? _pollingTimer;
  Timer? _cancelTimer;
  Timer? _timeoutTimer;
  bool _canCancel = false;
  bool _policeCancelled = false;
  String? _policeCancelReason;
  String? _policeCancelDetails;
  String _sosStatusText = 'SOS';
  String _sosSubText = 'Hold to activate';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _updateAnimationState();
    _checkExistingAlert();
  }
  
  Future<void> _checkExistingAlert() async {
    final box = await Hive.openBox('settings');
    final lastSosIdStr = box.get('last_sos_id');
    if (lastSosIdStr != null) {
      _activeAlertId = int.tryParse(lastSosIdStr.toString());
      if (_activeAlertId != null) {
        setState(() {
          _isActivated = true;
          _sosStatusText = 'RECONNECTING';
          _sosSubText = 'Checking alert status...';
        });
        _updateAnimationState();
        _startPolling();
      }
    }
  }

  void _updateAnimationState() {
    if (_isActivated) {
      if (_sosStatusText == 'HERE') {
        _pulseController.stop(); // Stop pulsing when they arrive
      } else {
        _pulseController.repeat(reverse: true); // Pulse fast or slow depending on state
      }
    } else {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pollingTimer?.cancel();
    _cancelTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _cancelSOSLocally({bool timeout = false}) async {
    if (_activeAlertId != null) {
      final api = context.read<ApiService>();
      await api.cancelSosAlert(_activeAlertId!, reason: timeout ? 'timeout' : null);
    }
    
    final box = await Hive.openBox('settings');
    await box.delete('last_sos_id');
    
    if (mounted) {
      setState(() {
        _isActivated = false;
        _activeAlertId = null;
        _canCancel = false;
        _policeCancelled = false;
        _sosStatusText = 'SOS';
        _sosSubText = 'Hold to activate';
      });
      _updateAnimationState();
      _pollingTimer?.cancel();
      _cancelTimer?.cancel();
      _timeoutTimer?.cancel();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(timeout ? 'No officers found nearby. Try again or call 112.' : 'SOS Alert Cancelled.'), 
          backgroundColor: timeout ? AppTheme.primaryRed : AppTheme.textMuted,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _showConfirmSheet() async {
    if (_isActivated) return;
    HapticFeedback.heavyImpact();
    
    if (!mounted) return;
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

    setState(() {
      _isActivated = true;
      _policeCancelled = false;
      _sosStatusText = 'SENDING';
      _sosSubText = 'Connecting to dispatch...';
    });
    _updateAnimationState();

    // Check for internet connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
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
      
      if (_activeAlertId != null) {
        final box = await Hive.openBox('settings');
        await box.put('last_sos_id', _activeAlertId);
        await box.put('last_sos_time', DateTime.now().toIso8601String());
        
        setState(() {
          _sosStatusText = 'SEARCHING';
          _sosSubText = 'Finding nearest officers...';
          _canCancel = true;
        });
        
        _cancelTimer?.cancel();
        _cancelTimer = Timer(const Duration(seconds: 10), () {
          if (mounted) setState(() => _canCancel = false);
        });
        
        _timeoutTimer?.cancel();
        _timeoutTimer = Timer(const Duration(minutes: 5), () async {
          if (mounted && _isActivated && _sosStatusText == 'SEARCHING') {
            await _cancelSOSLocally(timeout: true);
          }
        });
        
        _startPolling();
      }
    } else {
      setState(() {
        _isActivated = false;
        _policeCancelled = false;
        _sosStatusText = 'SOS';
        _sosSubText = 'Hold to activate';
      });
      _updateAnimationState();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Failed to send SOS'), backgroundColor: AppTheme.primaryRed),
      );
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_activeAlertId == null || !mounted) {
        timer.cancel();
        return;
      }
      
      final api = context.read<ApiService>();
      final res = await api.getAlertStatus(_activeAlertId!);
      
      if (!mounted) return;
      
      if (res['status'] == 'error') {
        // Just skip this tick if network drops
        return;
      }
      
      if (res['status'] == 'cancelled_by_police') {
        setState(() {
          _isActivated = false;
          _activeAlertId = null;
          _canCancel = false;
          _policeCancelled = true;
          _policeCancelReason = res['cancellation_reason'] ?? 'Not specified';
          _policeCancelDetails = res['cancellation_details'];
          _sosStatusText = 'CANCELLED';
          _sosSubText = 'By Police';
        });
        timer.cancel();
        _cancelTimer?.cancel();
        _timeoutTimer?.cancel();
        _updateAnimationState();
        
        final box = await Hive.openBox('settings');
        await box.delete('last_sos_id');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Police has cancelled your SOS.'), 
            backgroundColor: AppTheme.primaryRed,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      } else if (res['status'] == 'resolved' || res['status'] == 'false_alarm' || res['status'] == 'cancelled' || res['status'] == 'cancelled_by_citizen') {
        // Incident closed by officer
        setState(() {
          _isActivated = false;
          _activeAlertId = null;
          _canCancel = false;
          _policeCancelled = false;
          _sosStatusText = 'SOS';
          _sosSubText = 'Hold to activate';
        });
        timer.cancel();
        _cancelTimer?.cancel();
        _timeoutTimer?.cancel();
        _updateAnimationState();
        
        final box = await Hive.openBox('settings');
        await box.delete('last_sos_id');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incident has been resolved by the officer.'), 
            backgroundColor: AppTheme.accentGreen,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }
      
      if (res['is_dispatched'] == true && res['officer'] != null) {
        final dist = res['officer']['distance_km'];
        final badge = res['officer']['badge'];
        
        setState(() {
          if (dist != null && dist <= 0.2) {
            _sosStatusText = 'HERE';
            _sosSubText = 'Officer $badge is here';
          } else {
            _sosStatusText = 'ON WAY';
            _sosSubText = 'Officer $badge is arriving';
          }
        });
      } else {
        setState(() {
          _sosStatusText = 'SEARCHING';
          _sosSubText = 'Finding nearest officers...';
        });
      }
      _updateAnimationState();
    });
  }

  Future<void> _triggerOfflineSMS(double lat, double lng) async {
    final message = "EMERGENCY SOS: I need immediate assistance at my location: https://www.google.com/maps/search/?api=1&query=$lat,$lng";
    final uri = Uri.parse("sms:100?body=${Uri.encodeComponent(message)}");

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      if (mounted) {
        setState(() {
          _sosStatusText = 'SMS SENT';
          _sosSubText = 'Offline mode engaged';
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isActivated = false;
          _policeCancelled = false;
          _sosStatusText = 'SOS';
          _sosSubText = 'Hold to activate';
        });
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onLongPress: _isActivated ? null : _showConfirmSheet,
          onTap: () {
            if (_isActivated) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('SOS is active. Waiting for officer resolution.'),
                  backgroundColor: AppTheme.accentAmber,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
          child: Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (_sosStatusText == 'HERE' ? AppTheme.accentGreen : AppTheme.primaryRed).withOpacity(0.25),
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
                
                final baseColor = _sosStatusText == 'HERE' ? AppTheme.accentGreen : AppTheme.primaryRed;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isActivated && _sosStatusText != 'HERE') ...[
                      Transform.scale(scale: scale2, child: Container(width: 110, height: 110, decoration: BoxDecoration(shape: BoxShape.circle, color: baseColor.withOpacity(0.05)))),
                      Transform.scale(scale: scale1, child: Container(width: 110, height: 110, decoration: BoxDecoration(shape: BoxShape.circle, color: baseColor.withOpacity(0.1)))),
                    ],
                    Transform.scale(
                      scale: _isActivated ? 1.0 : 1.0 + (_pulseController.value * 0.04),
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _sosStatusText == 'HERE'
                                    ? [AppTheme.accentGreen, const Color(0xFF28A745)]
                                    : [AppTheme.primaryRed, const Color(0xFFC0392B)],
                          ),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _sosStatusText,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: _sosStatusText.length > 5 ? 20 : 32, 
                                  fontWeight: FontWeight.w900, 
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      child: Text(
                        _sosSubText,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        if (_canCancel && _isActivated)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: TextButton.icon(
              onPressed: () => _cancelSOSLocally(timeout: false),
              icon: const Icon(Icons.cancel, color: AppTheme.primaryRed),
              label: const Text('Cancel SOS', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        if (_policeCancelled)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Cancellation Details', style: TextStyle(fontWeight: FontWeight.bold)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reason: ${_policeCancelReason ?? "N/A"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(_policeCancelDetails ?? 'No extra details provided.'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _policeCancelled = false;
                            _sosStatusText = 'SOS';
                            _sosSubText = 'Hold to activate';
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Dismiss', style: TextStyle(color: AppTheme.primaryRed)),
                      )
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.primaryRed),
              label: const Text('View Reason', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
      ],
    );
  }
}
