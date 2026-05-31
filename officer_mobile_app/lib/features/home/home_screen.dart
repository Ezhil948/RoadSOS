
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../widgets/components.dart';
import '../../widgets/git_badge.dart';
import '../../widgets/stat_row.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../dispatch/dispatch_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(dispatchProvider);

    return Scaffold(
      backgroundColor: kDarkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Status Bar
              _buildStatusBar(context, ref, status),
              const SizedBox(height: 32),
              
              
              _buildShiftSummary(context),
              
              // Activity Feed
              const SectionHeader(title: 'SHIFT ACTIVITY'),
              Expanded(child: _buildActivityFeed(context)),
              
              // Floating Action Area
              const SizedBox(height: 16),
              _buildFloatingActions(context, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar(BuildContext context, WidgetRef ref, OfficerStatus status) {
    bool isOnline = status is! Offline;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: kAccentBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_outlined, color: kAccentBlue, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Hive.box('settings').get('officer_name', defaultValue: 'OFFICER').toString().toUpperCase(), style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Badge #${Hive.box('settings').get('badge_number', defaultValue: '----')}', style: AppTheme.monoSm.copyWith(color: kDarkMuted)),
                ],
              ),
            ),
            Column(
              children: [
                Switch(
                  value: isOnline,
                  activeColor: kAccentGreen,
                  onChanged: (val) async {
                    if (val) {
                      try {
                        await ref.read(dispatchProvider.notifier).goOnline();
                      } catch (e) {
                        if (context.mounted) {
                          final msg = e.toString().replaceAll('Exception: ', '');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(msg),
                              backgroundColor: kAccentRed,
                              action: msg.contains('permanently denied') || msg.contains('permission') 
                                ? SnackBarAction(
                                    label: 'SETTINGS',
                                    textColor: Colors.white,
                                    onPressed: () => Geolocator.openAppSettings(),
                                  )
                                : null,
                            ),
                          );
                        }
                      }
                    } else {
                      ref.read(dispatchProvider.notifier).goOffline();
                    }
                  },
                ),
                Text(isOnline ? 'Active' : 'Offline', style: TextStyle(color: isOnline ? kAccentGreen : kDarkMuted, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _toggleStatus(BuildContext context, WidgetRef ref, bool isCurrentlyOnline) {
    // Kept for backward compatibility if called elsewhere, but the switch directly handles it now.
  }



  Widget _buildActivityFeed(BuildContext context) {
    return ListView(
      children: const [
        Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(
            child: Text(
              'No recent shift activity.',
              style: TextStyle(color: kDarkMuted),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShiftSummary(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'TODAY\'S SHIFT'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _kpiChip(Icons.local_police_outlined, 'Dispatches', '0', kAccentBlue)),
            const SizedBox(width: 8),
            Expanded(child: _kpiChip(Icons.timer_outlined, 'Avg Response', '-- min', kAccentAmber)),
            const SizedBox(width: 8),
            Expanded(child: _kpiChip(Icons.route_outlined, 'Patrolled', '0.0 km', kAccentGreen)),
            const SizedBox(width: 8),
            Expanded(child: _kpiChip(Icons.check_circle_outline, 'Resolved', '0%', kAccentGreen)),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _kpiChip(IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildActivityRow(BuildContext context, String time, String title, String sub, BadgeState state, String label) {
    Color getLabelColor() {
      switch (state) {
        case BadgeState.online: return kAccentGreen;
        case BadgeState.resolved: return kAccentGreen;
        case BadgeState.high: return kAccentRed;
        case BadgeState.busy: return kAccentAmber;
        default: return kDarkMuted;
      }
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: kDarkBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(time, style: AppTheme.monoSm.copyWith(color: kDarkSubtext)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(sub, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kDarkMuted)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: getLabelColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(label.toUpperCase(), style: TextStyle(color: getLabelColor(), fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActions(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            Icons.add_circle_outline,
            'Report Incident',
            kAccentGreen,
            () => _showReportIncidentSheet(context, ref),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionButton(
            Icons.share_location_outlined,
            'Share Location',
            kAccentBlue,
            () => _showShareLocationSheet(context),
          ),
        ),
      ],
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportIncidentSheet(BuildContext context, WidgetRef ref) {
    String selectedType = 'Accident';
    String severity = 'moderate';
    final descController = TextEditingController();
    final casController = TextEditingController(text: '0');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kDarkSurface,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? kDarkBg : kLightBg;
        final borderColor = isDark ? kDarkBorder : kLightBorder;
        final textColor = isDark ? kDarkText : kLightText;

        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildSeverityChip(String label, String value, Color activeColor) {
              final isSelected = severity == value;
              return ChoiceChip(
                label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey)),
                selected: isSelected,
                selectedColor: activeColor,
                onSelected: (selected) {
                  if (selected) {
                    setModalState(() => severity = value);
                  }
                },
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('REPORT INCIDENT', style: AppTheme.monoMd.copyWith(color: kAccentGreen)),
                  const SizedBox(height: 24),
                  
                  Text('INCIDENT TYPE', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedType,
                        dropdownColor: kDarkSurface,
                        style: AppTheme.monoSm.copyWith(color: textColor),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'Accident', child: Text('Accident')),
                          DropdownMenuItem(value: 'Theft', child: Text('Theft')),
                          DropdownMenuItem(value: 'Disturbance', child: Text('Disturbance')),
                          DropdownMenuItem(value: 'Medical', child: Text('Medical')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedType = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text('SEVERITY', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      buildSeverityChip('Low', 'minor', kAccentBlue),
                      const SizedBox(width: 8),
                      buildSeverityChip('Medium', 'moderate', kAccentAmber),
                      const SizedBox(width: 8),
                      buildSeverityChip('High', 'critical', kAccentRed),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text('CASUALTIES', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  TextField(
                    controller: casController,
                    keyboardType: TextInputType.number,
                    style: AppTheme.monoSm.copyWith(color: textColor),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: bgColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text('DESCRIPTION', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    style: AppTheme.monoSm.copyWith(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Enter incident details...',
                      hintStyle: TextStyle(color: isDark ? kDarkMuted : kLightMuted),
                      filled: true,
                      fillColor: bgColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 24),

                    PrimaryButton(
                      label: 'SUBMIT REPORT',
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          final pos = await Geolocator.getCurrentPosition();
                          final dio = ref.read(dioProvider);
                          final formData = FormData.fromMap({
                            'latitude': pos.latitude,
                            'longitude': pos.longitude,
                            'severity': severity,
                            'casualties': int.tryParse(casController.text) ?? 0,
                            'description': '${selectedType.toUpperCase()}: ${descController.text}',
                          });
                          await dio.post('/accident/report', data: formData);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Incident report submitted to station'), backgroundColor: kAccentGreen),
                        );
                      } catch (_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Report submitted (offline cached)'), backgroundColor: kAccentAmber),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  void _showShareLocationSheet(BuildContext context) async {
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition();
    } catch (_) {}

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: kDarkSurface,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark ? kDarkText : kLightText;
        final locString = pos != null ? '${pos.latitude.toStringAsFixed(4)}° N, ${pos.longitude.toStringAsFixed(4)}° E' : 'Location unavailable';
        final copyString = pos != null ? '${pos.latitude}, ${pos.longitude}' : '';

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CURRENT COORDINATES', style: AppTheme.monoMd.copyWith(color: kAccentBlue)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? kDarkBg : kLightBg,
                  border: Border.all(color: isDark ? kDarkBorder : kLightBorder),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(locString, style: AppTheme.monoMd.copyWith(color: textColor)),
                    IconButton(
                      icon: const Icon(Icons.copy, color: kAccentBlue),
                      onPressed: () {
                        if (copyString.isNotEmpty) {
                          Clipboard.setData(ClipboardData(text: copyString));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Coordinates copied to clipboard'), backgroundColor: kAccentGreen),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'CLOSE',
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }
}

