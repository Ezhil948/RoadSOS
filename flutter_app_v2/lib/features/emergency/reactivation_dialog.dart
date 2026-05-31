import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ReactivationDialog extends StatelessWidget {
  const ReactivationDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.accentAmber, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Active SOS Detected',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text(
              'You triggered an SOS within the last 30 minutes. The police are already dispatched.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, 'update'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accentBlue,
                      backgroundColor: AppTheme.accentBlue.withOpacity(0.1),
                    ),
                    child: const Text('Update Location'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, 'new'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryRed,
                      backgroundColor: AppTheme.primaryRed.withOpacity(0.1),
                    ),
                    child: const Text('New SOS'),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }
}
