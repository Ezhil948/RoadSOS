import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../services/location_service.dart';
import '../../services/offline_sync_service.dart';
import '../../services/auth_service.dart';
import '../auth/phone_verify_screen.dart';
import 'report_screen.dart';
import '../../widgets/sos_button.dart';

class EmergencyTab extends StatelessWidget {
  const EmergencyTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: SOSButton(),
            ),
            const SizedBox(height: 20),
            _buildOfflineSyncCard(context),
            _buildLocationCard(context),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(height: 12),
            _buildQuickActions(context),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Important Numbers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(height: 12),
            _buildImportantNumbers(),
            const SizedBox(height: 24),
            _buildSafetyTips(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final loc = context.watch<LocationService>();
    Color statusColor = AppTheme.accentAmber;
    String statusText = 'Getting location...';
    if (loc.hasPermission && loc.currentPosition != null) {
      statusColor = AppTheme.accentGreen;
      statusText = 'Location Active';
    } else if (!loc.hasPermission && loc.errorMsg.isNotEmpty) {
      statusColor = AppTheme.primaryRed;
      statusText = 'Location Off';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('RoadSOS', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
              const Text('Emergency Response', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor,
                        boxShadow: [BoxShadow(color: statusColor.withOpacity(0.6), blurRadius: 6)],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: AppTheme.textMuted),
                onPressed: () async {
                  await context.read<AuthService>().logout();
                  if (!context.mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const PhoneVerifyScreen()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(BuildContext context) {
    final loc = context.watch<LocationService>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: (!loc.hasPermission)
            ? () async {
                final locService = context.read<LocationService>();
                await locService.requestPermission();
                if (locService.hasPermission) {
                  await locService.getCurrentLocation();
                }
              }
            : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: loc.hasPermission ? AppTheme.accentGreen.withOpacity(0.4) : AppTheme.accentAmber.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (loc.hasPermission ? AppTheme.accentGreen : AppTheme.accentAmber).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  loc.hasPermission ? Icons.location_on_rounded : Icons.location_off_rounded,
                  color: loc.hasPermission ? AppTheme.accentGreen : AppTheme.accentAmber,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.hasPermission ? 'Live Location Active' : 'Location Permission Required',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: loc.hasPermission ? AppTheme.accentGreen : AppTheme.accentAmber,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loc.hasPermission && loc.currentPosition != null
                          ? '${loc.currentPosition!.latitude.toStringAsFixed(4)}, ${loc.currentPosition!.longitude.toStringAsFixed(4)}'
                          : 'Tap to grant location access',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              if (!loc.hasPermission)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Enable', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accentBlue)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {'icon': Icons.camera_alt_rounded, 'label': 'Accident\nReport', 'color': AppTheme.accentAmber},
      {'icon': Icons.local_police_rounded, 'label': 'Call\nPolice', 'color': AppTheme.accentBlue, 'number': '100'},
      {'icon': Icons.local_hospital_rounded, 'label': 'Call\nAmbulance', 'color': AppTheme.accentGreen, 'number': '108'},
      {'icon': Icons.local_fire_department_rounded, 'label': 'Call\nFire Brigade', 'color': AppTheme.primaryRed, 'number': '101'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: actions.asMap().entries.map((entry) {
          final idx = entry.key;
          final action = entry.value;
          final color = action['color'] as Color;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: idx < actions.length - 1 ? 10 : 0),
              child: GestureDetector(
                onTap: () {
                  if (idx == 0) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen()));
                  }
                  // Phone calls for other actions handled natively
                },
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(0.3), width: 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(action['icon'] as IconData, color: color, size: 24),
                      const SizedBox(height: 6),
                      Text(
                        action['label'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color, height: 1.2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildImportantNumbers() {
    final numbers = [
      {'label': 'National Emergency', 'number': '112', 'color': AppTheme.primaryRed, 'icon': Icons.sos_rounded},
      {'label': 'Police', 'number': '100', 'color': AppTheme.accentBlue, 'icon': Icons.local_police_rounded},
      {'label': 'Ambulance', 'number': '108', 'color': AppTheme.accentGreen, 'icon': Icons.local_hospital_rounded},
      {'label': 'Highway Patrol', 'number': '1033', 'color': AppTheme.accentAmber, 'icon': Icons.directions_car_rounded},
    ];

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: numbers.length,
        itemBuilder: (ctx, i) {
          final item = numbers[i];
          final color = item['color'] as Color;
          return Container(
            width: 130,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderDark),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(item['icon'] as IconData, color: color, size: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['number'] as String,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color, fontFamily: 'monospace')),
                    Text(item['label'] as String,
                        style: const TextStyle(fontSize: 10, color: AppTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSafetyTips() {
    final tips = [
      {'icon': '🧘', 'title': 'Stay Calm', 'tip': 'Take a deep breath. Panicking worsens the situation. Assess injuries first, then call for help.'},
      {'icon': '🚨', 'title': 'Hazard Lights On', 'tip': 'Immediately turn on hazard lights after any accident to warn other drivers.'},
      {'icon': '📍', 'title': 'Know Your Location', 'tip': 'Note the nearest milestone, landmark, or road sign — it helps responders reach you faster.'},
      {'icon': '🚗', 'title': 'Move to Safety', 'tip': 'If the vehicle can move and no one is seriously injured, shift it to the road shoulder.'},
      {'icon': '🔴', 'title': 'Do Not Flee', 'tip': 'Leaving the scene of an accident is a criminal offence under Indian law.'},
      {'icon': '🆘', 'title': 'False Alarms', 'tip': 'You have 10 seconds to cancel an SOS after triggering it. Repeated false alerts will restrict your access.'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Safety Reminders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 12),
          ...tips.map((tip) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tip['icon'] as String, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tip['title'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                          const SizedBox(height: 3),
                          Text(tip['tip'] as String, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildOfflineSyncCard(BuildContext context) {
    final offline = context.watch<OfflineSyncService>();
    if (!offline.hasPendingReports) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: offline.isSyncing 
                    ? AppTheme.accentTeal.withOpacity(0.4) 
                    : AppTheme.accentAmber.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (offline.isSyncing ? AppTheme.accentTeal : AppTheme.accentAmber).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: offline.isSyncing
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentTeal),
                          ),
                        )
                      : const Icon(
                          Icons.cloud_off_rounded,
                          color: AppTheme.accentAmber,
                          size: 22,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${offline.queueCount} Offline Report${offline.queueCount > 1 ? "s" : ""} Queued',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: offline.isSyncing ? AppTheme.accentTeal : AppTheme.accentAmber,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        offline.isSyncing 
                            ? 'Uploading reports now...' 
                            : 'Waiting for network connection to sync...',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                if (!offline.isSyncing)
                  GestureDetector(
                    onTap: () => offline.syncPendingReports(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Sync Now',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentBlue,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
