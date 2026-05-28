import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/components.dart';
import 'dispatch_provider.dart';

class IncomingAlertScreen extends ConsumerStatefulWidget {
  const IncomingAlertScreen({super.key});

  @override
  ConsumerState<IncomingAlertScreen> createState() => _IncomingAlertScreenState();
}

class _IncomingAlertScreenState extends ConsumerState<IncomingAlertScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _countdownTimer;
  double _progress = 1.0;
  final int _timeoutSeconds = 30;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _startCountdown();
  }

  void _startCountdown() {
    int elapsed = 0;
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      elapsed += 100;
      if (mounted) {
        setState(() {
          _progress = 1.0 - (elapsed / (_timeoutSeconds * 1000));
        });
        if (_progress <= 0) {
          _countdownTimer?.cancel();
          _reject();
        }
      }
    });
  }

  void _reject() {
    ref.read(dispatchProvider.notifier).respondToDispatch(false);
    context.pop();
  }

  void _accept() {
    ref.read(dispatchProvider.notifier).respondToDispatch(true);
    context.pushReplacement('/dispatch/navigate');
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(dispatchProvider);
    if (status is! Dispatching) {
      // Failsafe in case status changes while screen is open
      return const Scaffold(backgroundColor: kDarkBg, body: Center(child: CircularProgressIndicator()));
    }

    final dispatch = status.dispatch;

    return Scaffold(
      backgroundColor: kDarkBg,
      body: SafeArea(
        child: Stack(
          children: [
            // Top Countdown bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: kDarkSurface,
                color: kAccentRed,
                minHeight: 4,
              ),
            ),
            
            Column(
              children: [
                const SizedBox(height: 16),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Container(width: 4, height: 40, color: kAccentRed),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('// INCOMING DISPATCH ' + '─' * 10, style: AppTheme.monoSm.copyWith(color: kDarkMuted)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('ALERT #${dispatch.alertId}', style: AppTheme.monoLg),
                                Text('[⚠ ${dispatch.severity.toUpperCase()}]', style: AppTheme.monoSm.copyWith(color: kAccentRed)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(flex: 1),
                
                // Metrics panel
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      MonoMetric(value: '${dispatch.etaMins} MIN', label: 'ETA'),
                      MonoMetric(value: '${dispatch.distanceKm} KM', label: 'Distance'),
                      MonoMetric(value: dispatch.severity.toUpperCase(), label: 'Severity'),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Message Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: kDarkBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('┌─ message ────────────────', style: AppTheme.monoSm.copyWith(color: kDarkMuted), maxLines: 1),
                        const SizedBox(height: 8),
                        Text('│  ${dispatch.message}', style: Theme.of(context).textTheme.bodyLarge),
                        Text('│  Reported by civilian user · just now', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 8),
                        Text('└──────────────────────────', style: AppTheme.monoSm.copyWith(color: kDarkMuted), maxLines: 1),
                      ],
                    ),
                  ),
                ),
                
                const Spacer(flex: 2),
                
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + (_pulseController.value * 0.02),
                            child: SizedBox(
                              height: 64,
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _accept,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kAccentGreen,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text('TAP TO ACCEPT', style: AppTheme.monoLg.copyWith(color: Colors.white)),
                              ),
                            ),
                          );
                        }
                      ),
                      const SizedBox(height: 16),
                      OutlinedPrimaryButton(
                        label: 'REJECT',
                        isDanger: true,
                        onPressed: _reject,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
