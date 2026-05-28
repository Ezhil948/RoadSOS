import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../utils/dialog_utils.dart';

class SOSButton extends StatefulWidget {
  const SOSButton({super.key});
  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton> with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;
  bool _activated = false;
  double _swipeProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scale = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _showSwipeToConfirm() {
    HapticFeedback.heavyImpact();
    
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            height: 250,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF161B22) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'CONFIRM EMERGENCY',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.redAccent, letterSpacing: 1.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'Swipe right to dispatch nearest officer.\nFalse alarms will permanently penalize your device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 32),
                
                // Swipe to Confirm UI
                GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setModalState(() {
                      _swipeProgress += details.primaryDelta! / 250.0;
                      _swipeProgress = _swipeProgress.clamp(0.0, 1.0);
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_swipeProgress > 0.8) {
                      Navigator.pop(ctx);
                      _triggerSOSFinal();
                    } else {
                      setModalState(() => _swipeProgress = 0.0);
                    }
                  },
                  child: Container(
                    height: 60,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text('SWIPE TO CONFIRM >>', 
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700, letterSpacing: 2)
                          ),
                        ),
                        Positioned(
                          left: _swipeProgress * 250,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 60,
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() => _swipeProgress = 0.0);
                  },
                  child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
                )
              ],
            ),
          );
        }
      )
    );
  }

  Future<void> _triggerSOSFinal() async {
    HapticFeedback.heavyImpact();
    setState(() => _activated = true);

    setState(() => _activated = true);

    final loc = context.read<LocationService>();
    final api = context.read<ApiService>();

    final lat = loc.currentPosition?.latitude ?? 12.8406;
    final lng = loc.currentPosition?.longitude ?? 80.1534;

    final result = await api.sendSOSAlert(
      latitude: lat,
      longitude: lng,
      severity: 'critical',
      message: 'Emergency SOS triggered',
    );

    if (mounted && result['alert_id'] != null) {
      _showDispatchConfirmation(context, result['alert_id']);
    }

    await Future.delayed(const Duration(seconds: 5));
    if (mounted) setState(() {
      _activated = false;
      _swipeProgress = 0.0;
    });
  }

  void _showDispatchConfirmation(BuildContext context, dynamic alertId) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.check_circle, color: Color(0xFF34C759), size: 28),
          const SizedBox(width: 12),
          const Text('Officer Notified', style: TextStyle(color: Colors.white, fontSize: 18)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alert #$alertId', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            const Text(
              'The nearest available officer has been notified and is responding to your location.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Color(0xFF34C759))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AnimatedBuilder(
            animation: _scale,
            builder: (context, child) {
              final scaleX = 1.0 + (_scale.value * 0.03);
              final scaleY = 1.0 + (_scale.value * 0.04);
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(scaleX, scaleY, 1.0),
                child: child,
              );
            },
            child: GestureDetector(
              onLongPress: _showSwipeToConfirm,
              child: Container(
                width: double.infinity,
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _activated
                        ? [const Color(0xFF34C759), const Color(0xFF28A745)]
                        : [const Color(0xFFFF3B30), const Color(0xFFD32F2F)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: (_activated ? Colors.green : Colors.red).withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 8,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_activated ? Icons.check_circle_outline : Icons.emergency_share, color: Colors.white, size: 24),
                      const SizedBox(height: 4),
                      Text(
                        _activated ? 'OFFICER DISPATCHED' : 'EMERGENCY SOS',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _activated ? 'Help is on the way' : 'Hold for 3 seconds to activate',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
