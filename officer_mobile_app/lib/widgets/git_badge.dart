import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

enum BadgeState { online, high, offline, busy, passed, resolved }

class GitBadge extends StatelessWidget {
  final BadgeState state;
  final String label;

  const GitBadge({super.key, required this.state, required this.label});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    
    switch (state) {
      case BadgeState.online:
      case BadgeState.resolved:
        color = kAccentGreen;
        icon = state == BadgeState.online ? Icons.circle : Icons.check;
        break;
      case BadgeState.high:
        color = kAccentAmber;
        icon = Icons.warning_rounded;
        break;
      case BadgeState.offline:
        color = kDarkMuted;
        icon = Icons.close;
        break;
      case BadgeState.busy:
      case BadgeState.passed:
        color = kAccentBlue;
        icon = Icons.arrow_forward;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}
