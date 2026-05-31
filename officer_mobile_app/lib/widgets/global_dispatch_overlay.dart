import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/dispatch/dispatch_provider.dart';
import '../core/models/dispatch.dart';

class GlobalDispatchOverlay extends ConsumerStatefulWidget {
  const GlobalDispatchOverlay({super.key});

  @override
  ConsumerState<GlobalDispatchOverlay> createState() => _GlobalDispatchOverlayState();
}

class _GlobalDispatchOverlayState extends ConsumerState<GlobalDispatchOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _timerController;
  final int _timeoutSeconds = 30;
  DispatchModel? _currentDispatch;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _timeoutSeconds),
    );

    _timerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Timer ran out
        ref.read(dispatchProvider.notifier).missDispatch();
      }
    });
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<OfficerStatus>(dispatchProvider, (previous, current) {
      if (current is Dispatching) {
        if (_currentDispatch?.alertId != current.dispatch.alertId) {
          setState(() => _currentDispatch = current.dispatch);
          _timerController.forward(from: 0.0);
        }
      } else {
        if (_timerController.isAnimating) {
          _timerController.stop();
        }
        if (_currentDispatch != null) {
          setState(() => _currentDispatch = null);
        }
      }
    });

    final status = ref.watch(dispatchProvider);
    final isDispatching = status is Dispatching;

    final topOffset = isDispatching ? 0.0 : -300.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      top: topOffset,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
            color: isDark ? kDarkSurface : kLightSurface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: kAccentRed.withOpacity(0.5), width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  color: (_currentDispatch?.type == 'officer_backup') ? kAccentBlue.withOpacity(0.2) : kAccentRed.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    children: [
                      Icon(
                        (_currentDispatch?.type == 'officer_backup') ? Icons.local_police : Icons.warning_amber_rounded,
                        color: (_currentDispatch?.type == 'officer_backup') ? kAccentBlue : kAccentRed,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (_currentDispatch?.type == 'officer_backup') ? 'OFFICER NEEDS BACKUP' : 'INCOMING DISPATCH',
                              style: AppTheme.monoMd.copyWith(
                                color: (_currentDispatch?.type == 'officer_backup') ? kAccentBlue : kAccentRed,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_currentDispatch != null)
                              Text(
                                (_currentDispatch!.type == 'officer_backup')
                                  ? '${_currentDispatch!.officerName?.toUpperCase() ?? 'UNKNOWN OFFICER'} - URGENT'
                                  : '${_currentDispatch!.message.toUpperCase()} - ${_currentDispatch!.severity.toUpperCase()}',
                                style: AppTheme.monoSm.copyWith(color: isDark ? kDarkText : kLightText),
                              ),
                            if (_currentDispatch?.type == 'citizen_alert' && _currentDispatch!.reporters.length > 1)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: kAccentAmber.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                  child: Text(
                                    '${_currentDispatch!.reporters.length} REPORTS AGGREGATED',
                                    style: AppTheme.monoSm.copyWith(color: kAccentAmber, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_currentDispatch != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (_currentDispatch?.type == 'officer_backup') ? kAccentBlue.withOpacity(0.2) : kAccentRed.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_currentDispatch!.distanceKm} KM',
                            style: AppTheme.monoSm.copyWith(
                              color: (_currentDispatch?.type == 'officer_backup') ? kAccentBlue : kAccentRed,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Actions
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Reject
                      Expanded(
                        child: InkWell(
                          onTap: () => ref.read(dispatchProvider.notifier).respondToDispatch(false),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: kAccentRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: kAccentRed.withOpacity(0.3)),
                            ),
                            child: const Center(
                              child: Icon(Icons.close, color: kAccentRed, size: 32),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Accept
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () => ref.read(dispatchProvider.notifier).respondToDispatch(true),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: kAccentGreen,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: kAccentGreen.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            ),
                            child: const Center(
                              child: Icon(Icons.check, color: Colors.white, size: 32),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Timer Line
                AnimatedBuilder(
                  animation: _timerController,
                  builder: (context, child) {
                    final remaining = 1.0 - _timerController.value;
                    Color barColor;
                    if (_timerController.value > 0.66) {
                      barColor = kAccentRed;       // Last third — red (urgent)
                    } else if (_timerController.value > 0.33) {
                      barColor = kAccentAmber;     // Middle third — amber (warning)
                    } else {
                      barColor = kAccentGreen;     // First third — green (plenty of time)
                    }
                    
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 4,
                        width: MediaQuery.of(context).size.width * remaining,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
