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
import 'dart:ui' show FontFeature;
import '../services/auth_service.dart';

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
  bool _incidentResolved = false;
  bool _incidentFalseAlarm = false;
  Map<String, dynamic>? _resolvedOfficerInfo;
  String? _closureNotes;
  String? _closureCategory;
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
    final box = Hive.box('settings');
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
      String? reason = timeout ? 'timeout' : null;
      if (!timeout && _canCancel) {
        reason = 'false_alarm_grace_period';
      }
      await api.cancelSosAlert(_activeAlertId!, reason: reason);
    }
    
    final box = Hive.box('settings');
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
    if (_isActivated) return; // Prevent duplicate SOS triggers
    
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

    final auth = context.read<AuthService>();

    final result = await api.sendSOSAlert(
      latitude: loc.currentPosition!.latitude,
      longitude: loc.currentPosition!.longitude,
      severity: 'critical',
      message: 'Emergency SOS triggered',
      citizenName: auth.citizenName.isNotEmpty ? auth.citizenName : null,
      citizenPhone: auth.citizenPhone.isNotEmpty ? auth.citizenPhone : null,
    );

    if (!mounted) return;

    if (result['status'] != 'error') {
      final alertId = result['alert_id'];
      _activeAlertId = alertId is int ? alertId : int.tryParse(alertId.toString());
      
      if (_activeAlertId != null) {
        final box = Hive.box('settings');
        await box.put('last_sos_id', _activeAlertId);
        await box.put('last_sos_time', DateTime.now().toIso8601String());
        
        setState(() {
          _sosStatusText = 'SEARCHING';
          _sosSubText = 'Finding nearest officers...';
          _canCancel = true;
        });
        
        _cancelTimer?.cancel();
        _cancelTimer = Timer(const Duration(seconds: 15), () {
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
      
      if (_activeAlertId == null) {
        timer.cancel();
        return;
      }
      
      if (res['status'] == 'error') {
        // Just skip this tick if network drops
        return;
      }
      
      // RESOLVED — officer marked it clear
      if (res['status'] == 'resolved') {
        final box = Hive.box('settings');
        await box.delete('last_sos_id');
        timer.cancel();
        _cancelTimer?.cancel();
        _timeoutTimer?.cancel();
        if (!mounted) return;
        setState(() {
          _isActivated = false;
          _activeAlertId = null;
          _canCancel = false;
          _policeCancelled = false;
          _incidentResolved = true;
          _incidentFalseAlarm = false;
          _resolvedOfficerInfo = res['officer'];
          _closureNotes = res['closure_notes'];
          _closureCategory = res['category'];
          _sosStatusText = 'CLEARED';
          _sosSubText = 'Officer resolved your case';
        });
        _updateAnimationState();
        return;
      }
      
      // FALSE ALARM — officer or citizen marked it as false
      if (res['status'] == 'false_alarm') {
        final box = Hive.box('settings');
        await box.delete('last_sos_id');
        timer.cancel();
        _cancelTimer?.cancel();
        _timeoutTimer?.cancel();
        if (!mounted) return;
        setState(() {
          _isActivated = false;
          _activeAlertId = null;
          _canCancel = false;
          _policeCancelled = false;
          _incidentResolved = false;
          _incidentFalseAlarm = true;
          _resolvedOfficerInfo = res['officer'];
          _sosStatusText = 'FALSE ALARM';
          _sosSubText = 'Marked by officer';
        });
        _updateAnimationState();
        return;
      }
      
      // CANCELLED BY POLICE — officer stood down (cannot respond)
      if (res['status'] == 'cancelled_by_police') {
        final box = Hive.box('settings');
        await box.delete('last_sos_id');
        timer.cancel();
        _cancelTimer?.cancel();
        _timeoutTimer?.cancel();
        if (!mounted) return;
        setState(() {
          _isActivated = false;
          _activeAlertId = null;
          _canCancel = false;
          _policeCancelled = true;
          _incidentResolved = false;
          _incidentFalseAlarm = false;
          _policeCancelReason = res['cancellation_reason'];
          _policeCancelDetails = res['cancellation_details'];
          _resolvedOfficerInfo = res['officer'];
          _sosStatusText = 'STOOD DOWN';
          _sosSubText = 'Officer cannot respond';
        });
        _updateAnimationState();
        return;
      }
      
      // CANCELLED — citizen cancelled or timed out
      if (res['status'] == 'cancelled' || res['status'] == 'cancelled_by_citizen') {
        final box = Hive.box('settings');
        await box.delete('last_sos_id');
        timer.cancel();
        _cancelTimer?.cancel();
        _timeoutTimer?.cancel();
        if (!mounted) return;
        setState(() {
          _isActivated = false;
          _activeAlertId = null;
          _canCancel = false;
          _policeCancelled = false;
          _incidentResolved = false;
          _incidentFalseAlarm = false;
          _sosStatusText = 'SOS';
          _sosSubText = 'Hold to activate';
        });
        _updateAnimationState();
        return;
      } else if (res['status'] == 'no_officers_available') {
        setState(() {
          _isActivated = false;
          _activeAlertId = null;
          _canCancel = false;
          _policeCancelled = false;
          _sosStatusText = 'NO OFFICERS';
          _sosSubText = 'Call 112 immediately';
        });
        timer.cancel();
        _cancelTimer?.cancel();
        _timeoutTimer?.cancel();
        _updateAnimationState();
        
        final box = Hive.box('settings');
        await box.delete('last_sos_id');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No officers available nearby. Please call 112.'), 
            backgroundColor: AppTheme.primaryRed,
            duration: Duration(seconds: 10),
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

  void _showIncidentResolutionSheet() {
    final bool isResolved = _incidentResolved;
    final bool isFalseAlarm = _incidentFalseAlarm;
    final bool isCancelledByPolice = _policeCancelled;

    String headerTitle;
    Color headerColor;
    IconData headerIcon;

    if (isResolved) {
      headerTitle = 'INCIDENT CLEARED';
      headerColor = AppTheme.accentGreen;
      headerIcon = Icons.check_circle_rounded;
    } else if (isFalseAlarm) {
      headerTitle = 'FALSE ALARM';
      headerColor = AppTheme.accentAmber;
      headerIcon = Icons.warning_amber_rounded;
    } else {
      headerTitle = 'OFFICER STOOD DOWN';
      headerColor = AppTheme.primaryRed;
      headerIcon = Icons.block_rounded;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: headerColor.withOpacity(0.3)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            children: [
              // Drag handle
              Center(child: Container(
                margin: const EdgeInsets.only(bottom: 20, top: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              )),

              // Header
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: headerColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(headerIcon, color: headerColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headerTitle, style: TextStyle(
                      color: headerColor, fontWeight: FontWeight.w900,
                      fontSize: 18, letterSpacing: 1.0,
                    )),
                    const SizedBox(height: 4),
                    Text('SOS Alert #$_activeAlertId', style: TextStyle(
                      color: AppTheme.textMuted, fontSize: 12,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )),
                  ],
                )),
              ]),

              const SizedBox(height: 24),
              Divider(color: Colors.white.withOpacity(0.08)),
              const SizedBox(height: 16),

              // Officer Section
              if (_resolvedOfficerInfo != null) ...[
                _detailLabel('RESPONDING OFFICER'),
                _detailRow(
                  Icons.local_police_rounded,
                  '${_resolvedOfficerInfo!['name'] ?? 'Officer'} • Badge ${_resolvedOfficerInfo!['badge'] ?? 'N/A'}',
                  AppTheme.accentBlue,
                ),
                const SizedBox(height: 16),
              ],

              // Resolution details (for resolved)
              if (isResolved) ...[
                if (_closureCategory != null) ...[
                  _detailLabel('INCIDENT CATEGORY'),
                  _detailRow(Icons.category_rounded, _closureCategory!.toUpperCase(), AppTheme.accentGreen),
                  const SizedBox(height: 16),
                ],
                if (_closureNotes != null && _closureNotes!.isNotEmpty) ...[
                  _detailLabel('OFFICER\'S NOTES'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Text(_closureNotes!, style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14, height: 1.5,
                    )),
                  ),
                  const SizedBox(height: 16),
                ],
              ],

              // False alarm info
              if (isFalseAlarm) ...[
                _detailLabel('NOTE'),
                _detailRow(Icons.info_outline_rounded,
                  'This alert was marked as a false alarm. No penalty has been applied if you cancelled within the grace period.',
                  AppTheme.accentAmber),
                const SizedBox(height: 16),
              ],

              // Stood down reason
              if (isCancelledByPolice) ...[
                _detailLabel('REASON'),
                _detailRow(Icons.block_rounded,
                  _policeCancelReason ?? 'Not specified', AppTheme.primaryRed),
                if (_policeCancelDetails != null && _policeCancelDetails!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _detailLabel('OFFICER\'S DETAILS'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_policeCancelDetails!, style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14, height: 1.5,
                    )),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.accentAmber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accentAmber.withOpacity(0.2)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.phone_rounded, color: AppTheme.accentAmber, size: 18),
                    SizedBox(width: 10),
                    Expanded(child: Text(
                      'Another officer may still respond. If in danger, call 112 immediately.',
                      style: TextStyle(color: AppTheme.accentAmber, fontSize: 13),
                    )),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // Dismiss button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _incidentResolved = false;
                      _incidentFalseAlarm = false;
                      _policeCancelled = false;
                      _sosStatusText = 'SOS';
                      _sosSubText = 'Hold to activate';
                    });
                    _updateAnimationState();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: headerColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('UNDERSTOOD', style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5,
                  )),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widgets
  Widget _detailLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(
      color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5,
    )),
  );

  Widget _detailRow(IconData icon, String text, Color color) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600))),
    ],
  );

  Color get _buttonColor {
    if (_sosStatusText == 'CLEARED') return AppTheme.accentGreen;
    if (_sosStatusText == 'FALSE ALARM') return AppTheme.accentAmber;
    if (_sosStatusText == 'STOOD DOWN') return AppTheme.accentAmber;
    if (_sosStatusText == 'NO OFFICERS') return AppTheme.accentAmber;
    if (_sosStatusText == 'HERE') return AppTheme.accentGreen;
    return AppTheme.primaryRed;
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
                
                final baseColor = _buttonColor;

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
                            colors: [_buttonColor, _buttonColor.withOpacity(0.75)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
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
        if (_incidentResolved || _incidentFalseAlarm || _policeCancelled)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: TextButton.icon(
              onPressed: _showIncidentResolutionSheet,
              icon: Icon(
                _incidentResolved ? Icons.check_circle_rounded : 
                _incidentFalseAlarm ? Icons.warning_amber_rounded : Icons.block_rounded,
                color: _incidentResolved ? AppTheme.accentGreen : 
                       _incidentFalseAlarm ? AppTheme.accentAmber : AppTheme.primaryRed,
              ),
              label: Text(
                _incidentResolved ? 'View Resolution Details' : 
                _incidentFalseAlarm ? 'View False Alarm Info' : 'View Reason',
                style: TextStyle(
                  color: _incidentResolved ? AppTheme.accentGreen :
                         _incidentFalseAlarm ? AppTheme.accentAmber : AppTheme.primaryRed,
                  fontWeight: FontWeight.bold, fontSize: 16,
                ),
              ),
            ),
          ),
        if (!_isActivated && _sosStatusText == 'NO OFFICERS')
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: TextButton.icon(
              onPressed: () {
                launchUrl(Uri.parse('tel:112'));
              },
              icon: const Icon(Icons.phone, color: AppTheme.primaryRed),
              label: const Text('Call 112 Now', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
      ],
    );
  }
}
