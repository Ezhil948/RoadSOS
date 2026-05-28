import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/models/dispatch.dart';
import 'git_badge.dart';

class StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const StatRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: kDarkMuted),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: CustomPaint(painter: DottedLinePainter()),
            ),
          ),
          Text(value, style: AppTheme.monoMd),
        ],
      ),
    );
  }
}

class DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kDarkBorder
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, size.height / 2), Offset(startX + 2, size.height / 2), paint);
      startX += 6;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: kAccentBlue,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 12,
            ),
      ),
    );
  }
}

class AlertCard extends StatelessWidget {
  final DispatchModel alert;
  final BadgeState badgeState;
  final String badgeLabel;

  const AlertCard({
    super.key,
    required this.alert,
    required this.badgeState,
    required this.badgeLabel,
  });

  @override
  Widget build(BuildContext context) {
    Color severityColor = alert.severity == 'high' ? kAccentRed : kAccentAmber;
    
    return Container(
      decoration: BoxDecoration(
        color: kDarkSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kDarkBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 90,
            decoration: BoxDecoration(
              color: severityColor,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 16, color: severityColor),
                          const SizedBox(width: 4),
                          Text(alert.severity.toUpperCase(), style: AppTheme.monoSm.copyWith(color: severityColor)),
                        ],
                      ),
                      Text('Alert #${alert.alertId}', style: AppTheme.monoMd),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    alert.message,
                    style: Theme.of(context).textTheme.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('── ${alert.distanceKm} km · ${alert.etaMins}m ETA ── ', style: AppTheme.monoSm.copyWith(color: kDarkMuted)),
                      GitBadge(state: badgeState, label: badgeLabel),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
