import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SosConfirmSheet extends StatefulWidget {
  final VoidCallback onConfirm;
  const SosConfirmSheet({super.key, required this.onConfirm});

  @override
  State<SosConfirmSheet> createState() => _SosConfirmSheetState();
}

class _SosConfirmSheetState extends State<SosConfirmSheet> {
  double _swipeProgress = 0.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            '⚠️ CONFIRM EMERGENCY',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primaryRed),
          ),
          const SizedBox(height: 8),
          const Text(
            'This will dispatch the nearest officer to your location.\nFalse alerts permanently restrict your access.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _swipeProgress += details.primaryDelta! / 250.0;
                _swipeProgress = _swipeProgress.clamp(0.0, 1.0);
              });
            },
            onHorizontalDragEnd: (details) {
              if (_swipeProgress > 0.85) {
                Navigator.pop(context);
                widget.onConfirm();
              } else {
                setState(() => _swipeProgress = 0.0);
              }
            },
            child: Container(
              height: 56,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withOpacity(0.2),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Text(
                      'SWIPE RIGHT TO CONFIRM',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: AppTheme.primaryRed),
                    ),
                  ),
                  Positioned(
                    left: _swipeProgress * (MediaQuery.of(context).size.width - 48 - 56), // max translation
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppTheme.primaryRed, Color(0xFFD32F2F)]),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          ),
        ],
      ),
    );
  }
}
