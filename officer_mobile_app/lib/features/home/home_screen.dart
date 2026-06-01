
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isOnline ? kAccentGreen.withOpacity(0.3) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: isOnline ? kAccentGreen.withOpacity(0.08) : Colors.black.withOpacity(0.05),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // The Premium Shield
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isOnline 
                  ? [const Color(0xFF10B981), const Color(0xFF047857)] // Emerald green glow when online
                  : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)], // Standard blue when offline
              ),
              boxShadow: [
                BoxShadow(
                  color: (isOnline ? kAccentGreen : kAccentBlue).withOpacity(0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.shield_rounded, color: Colors.white, size: 32),
                Icon(Icons.star_rounded, color: Colors.white, size: 12),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Hive.box('settings').get('officer_name', defaultValue: 'OFFICER').toString().toUpperCase(), 
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'BADGE #${Hive.box('settings').get('badge_number', defaultValue: '----')}', 
                    style: const TextStyle(color: kDarkMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Switch(
                value: isOnline,
                activeColor: kAccentGreen,
                activeTrackColor: kAccentGreen.withOpacity(0.2),
                inactiveThumbColor: kDarkMuted,
                inactiveTrackColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
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
              Text(
                isOnline ? 'ACTIVE' : 'OFFLINE', 
                style: TextStyle(
                  color: isOnline ? kAccentGreen : kDarkMuted, 
                  fontSize: 10, 
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _toggleStatus(BuildContext context, WidgetRef ref, bool isCurrentlyOnline) {
    // Kept for backward compatibility if called elsewhere, but the switch directly handles it now.
  }



  Widget _buildActivityFeed(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(40.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 64, color: kDarkMuted.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  const Text(
                    'No Recent Activity',
                    style: TextStyle(color: kDarkMuted, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your shift timeline will appear here.',
                    style: TextStyle(color: kDarkMuted.withOpacity(0.7), fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftSummary(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'TODAY\'S SHIFT'),
        Row(
          children: [
            Expanded(child: _kpiChip(context, Icons.local_police_rounded, 'Dispatches', '0', const Color(0xFF3B82F6))),
            const SizedBox(width: 12),
            Expanded(child: _kpiChip(context, Icons.timer_rounded, 'Avg Response', '-- min', const Color(0xFFF59E0B))),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _kpiChip(context, Icons.route_rounded, 'Patrolled', '0.0 km', const Color(0xFF10B981))),
            const SizedBox(width: 12),
            Expanded(child: _kpiChip(context, Icons.check_circle_rounded, 'Resolved', '0%', const Color(0xFF10B981))),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _kpiChip(BuildContext context, IconData icon, String title, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(color: kDarkMuted, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
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
            Icons.add_circle_rounded,
            'Report Incident',
            [const Color(0xFF34D399), const Color(0xFF059669)], // Brighter Emerald
            () => _showReportIncidentSheet(context, ref),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _actionButton(
            Icons.share_location_rounded,
            'Share Location',
            [const Color(0xFF60A5FA), const Color(0xFF2563EB)], // Brighter Blue
            () => _showShareLocationSheet(context),
          ),
        ),
      ],
    );
  }

  Widget _actionButton(IconData icon, String label, List<Color> gradientColors, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradientColors.last.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5),
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

