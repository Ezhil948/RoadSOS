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
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white, // Sleek dark slate
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: (_currentDispatch?.type == 'officer_backup') 
                    ? const Color(0xFF3B82F6).withOpacity(0.3) 
                    : const Color(0xFFEF4444).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header Section ──────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: (_currentDispatch?.type == 'officer_backup')
                            ? [const Color(0xFF1E3A8A).withOpacity(0.4), const Color(0xFF1E40AF).withOpacity(0.1)]
                            : [const Color(0xFF7F1D1D).withOpacity(0.4), const Color(0xFF991B1B).withOpacity(0.1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (_currentDispatch?.type == 'officer_backup')
                                ? const Color(0xFF3B82F6).withOpacity(0.15)
                                : const Color(0xFFEF4444).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            (_currentDispatch?.type == 'officer_backup') 
                                ? Icons.local_police_rounded 
                                : Icons.warning_rounded,
                            color: (_currentDispatch?.type == 'officer_backup') 
                                ? const Color(0xFF60A5FA) 
                                : const Color(0xFFF87171),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (_currentDispatch?.type == 'officer_backup') 
                                    ? 'OFFICER NEEDS BACKUP' 
                                    : 'INCOMING DISPATCH',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (_currentDispatch != null)
                                Text(
                                  (_currentDispatch!.type == 'officer_backup')
                                      ? '${_currentDispatch!.officerName ?? 'UNKNOWN OFFICER'}'
                                      : '${_currentDispatch!.message}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.85),
                                    height: 1.3,
                                  ),
                                ),
                              if (_currentDispatch?.type == 'citizen_alert' && _currentDispatch!.reporters.length > 1)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD97706).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.people_alt_rounded, color: Color(0xFFFCD34D), size: 12),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${_currentDispatch!.reporters.length} REPORTS AGGREGATED',
                                          style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_currentDispatch != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: (_currentDispatch?.type == 'officer_backup') 
                                  ? const Color(0xFF2563EB).withOpacity(0.2) 
                                  : const Color(0xFFDC2626).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: (_currentDispatch?.type == 'officer_backup') 
                                    ? const Color(0xFF3B82F6).withOpacity(0.5) 
                                    : const Color(0xFFEF4444).withOpacity(0.5),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${_currentDispatch!.distanceKm}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: (_currentDispatch?.type == 'officer_backup') 
                                        ? const Color(0xFF93C5FD) 
                                        : const Color(0xFFFCA5A5),
                                  ),
                                ),
                                Text(
                                  'KM AWAY',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    color: (_currentDispatch?.type == 'officer_backup') 
                                        ? const Color(0xFF93C5FD).withOpacity(0.8) 
                                        : const Color(0xFFFCA5A5).withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // ── Action Buttons ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: Row(
                      children: [
                        // Reject Button
                        Expanded(
                          child: InkWell(
                            onTap: () => ref.read(dispatchProvider.notifier).respondToDispatch(false),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0)),
                              ),
                              child: Center(
                                child: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 28),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Accept Button
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: () => ref.read(dispatchProvider.notifier).respondToDispatch(true),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF059669), Color(0xFF10B981)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              ),
                              child: const Center(
                                child: Icon(Icons.check_rounded, color: Colors.white, size: 28),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // ── Timer Line ──────────────────────────────────────
                  AnimatedBuilder(
                    animation: _timerController,
                    builder: (context, child) {
                      final remaining = 1.0 - _timerController.value;
                      Color barColor;
                      if (_timerController.value > 0.75) {
                        barColor = const Color(0xFFEF4444); // Urgent red
                      } else if (_timerController.value > 0.5) {
                        barColor = const Color(0xFFF59E0B); // Warning amber
                      } else {
                        barColor = const Color(0xFF10B981); // Safe green
                      }
                      
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 4,
                          width: MediaQuery.of(context).size.width * remaining,
                          color: barColor,
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
