import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';

import 'dispatch_provider.dart';
import 'navigation_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/components.dart';
import '../../widgets/stat_row.dart';

class ResolutionScreen extends ConsumerStatefulWidget {
  const ResolutionScreen({super.key});

  @override
  ConsumerState<ResolutionScreen> createState() => _ResolutionScreenState();
}

class _ResolutionScreenState extends ConsumerState<ResolutionScreen> {
  late TextEditingController _notesController;
  bool _isFalseAlarm = false;
  bool _showSuccessAnimation = false;
  bool _isSubmitting = false;
  late String _arrivalTimeStr;

  @override
  void initState() {
    super.initState();
    _arrivalTimeStr = DateFormat('hh:mm a').format(DateTime.now());
    // Pre-populate with notes written during navigation
    _notesController = TextEditingController(text: ref.read(dispatchNoteProvider));
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _submitResolution() async {
    if (_isFalseAlarm) {
      // Show confirmation dialog for False Alarm
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? kDarkSurface : kLightSurface,
            title: const Text('Confirm False Alarm', style: TextStyle(color: kAccentRed)),
            content: const Text(
              'This will penalize the civilian\'s trust score by 50 points. Are you sure?',
              style: TextStyle(fontSize: 15),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? kDarkText : kLightText,
                  side: BorderSide(color: isDark ? kDarkBorder : kLightBorder),
                ),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: kAccentRed),
                child: const Text('CONFIRM', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
      if (confirm != true) return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Make API Call
    await ref.read(dispatchProvider.notifier).resolveDispatch(
      _isFalseAlarm,
      _notesController.text,
    );

    // Clear the note provider
    ref.read(dispatchNoteProvider.notifier).state = '';

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _showSuccessAnimation = true;
      });

      // Show Lottie animation, wait 1.5 seconds, then go home
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          context.go('/');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(dispatchProvider);
    if (status is! Arrived && !_showSuccessAnimation) {
      // If we got here but not in Arrived state, route back to home
      return const Scaffold(backgroundColor: kDarkBg, body: Center(child: CircularProgressIndicator()));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? kDarkBg : kLightBg;
    final surfaceColor = isDark ? kDarkSurface : kLightSurface;
    final borderColor = isDark ? kDarkBorder : kLightBorder;
    final textColor = isDark ? kDarkText : kLightText;
    final subtextColor = isDark ? kDarkSubtext : kLightSubtext;
    final mutedColor = isDark ? kDarkMuted : kLightMuted;

    if (_showSuccessAnimation) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: Lottie.asset(
                  'assets/lottie/success.json',
                  repeat: false,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'DISPATCH RESOLVED',
                style: AppTheme.monoLg.copyWith(color: kAccentGreen),
              ),
              const SizedBox(height: 8),
              Text(
                'Logs updated and sync complete.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    final dispatch = (status as Arrived).dispatch;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('RESOLVE DISPATCH', style: TextStyle(color: textColor)),
        backgroundColor: bgColor,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: 'DISPATCH #${dispatch.alertId} — RESOLUTION'),
              
              // Arrival Stats Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    StatRow(
                      icon: Icons.access_time_filled,
                      label: 'Arrived at',
                      value: _arrivalTimeStr,
                    ),
                    const SizedBox(height: 8),
                    StatRow(
                      icon: Icons.speed,
                      label: 'Response time',
                      value: '${dispatch.etaMins}m 00s', // Based on dispatch ETA
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kAccentGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '[▲ personal best!]',
                            style: AppTheme.monoSm.copyWith(color: kAccentGreen, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Text('What was the outcome?', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // MARK RESOLVED Button
              InkWell(
                onTap: () {
                  setState(() {
                    _isFalseAlarm = false;
                  });
                },
                child: Container(
                  height: 56,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: !_isFalseAlarm ? kAccentGreen : Colors.transparent,
                    border: Border.all(color: !_isFalseAlarm ? kAccentGreen : borderColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check, color: !_isFalseAlarm ? Colors.white : mutedColor),
                      const SizedBox(width: 8),
                      Text(
                        'MARK RESOLVED',
                        style: TextStyle(
                          color: !_isFalseAlarm ? Colors.white : textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              Center(
                child: Text(
                  '─── or ────────────────────────────────────────',
                  style: AppTheme.monoSm.copyWith(color: mutedColor),
                ),
              ),
              const SizedBox(height: 16),

              // FLAG AS FALSE ALARM Button
              InkWell(
                onTap: () {
                  setState(() {
                    _isFalseAlarm = true;
                  });
                },
                child: Container(
                  height: 48,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _isFalseAlarm ? kAccentRed.withOpacity(0.1) : Colors.transparent,
                    border: Border.all(color: _isFalseAlarm ? kAccentRed : borderColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.close, color: _isFalseAlarm ? kAccentRed : mutedColor),
                      const SizedBox(width: 8),
                      Text(
                        'FLAG AS FALSE ALARM',
                        style: TextStyle(
                          color: _isFalseAlarm ? kAccentRed : textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Notes Input
              Text('Notes (optional):', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: _notesController,
                  maxLines: null,
                  expands: true,
                  style: AppTheme.monoSm.copyWith(color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Add notes about the incident resolution...',
                    hintStyle: TextStyle(color: mutedColor),
                    filled: true,
                    fillColor: surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: _isFalseAlarm ? kAccentRed : kAccentGreen),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Submit Button
              PrimaryButton(
                label: 'SUBMIT RESOLUTION',
                isLoading: _isSubmitting,
                isDanger: _isFalseAlarm,
                onPressed: _submitResolution,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
