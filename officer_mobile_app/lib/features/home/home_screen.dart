import 'dart:math' show max;
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
              
              // Shift Stats
              const WeeklyStatsPanel(),
              const SizedBox(height: 32),
              
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
              child: const Icon(Icons.person, color: kAccentBlue, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Hive.box('settings').get('officer_name', defaultValue: 'OFFICER').toString().toUpperCase(), style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Badge #${Hive.box('settings').get('badge_number', defaultValue: '0000')} • Shift: 06:00 – 18:00', style: AppTheme.monoSm.copyWith(color: kDarkMuted)),
                ],
              ),
            ),
            Column(
              children: [
                Switch(
                  value: isOnline,
                  activeColor: kAccentGreen,
                  onChanged: (val) {
                    if (val) {
                      ref.read(dispatchProvider.notifier).goOnline();
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
      children: [
        _buildActivityRow(context, '10:42', 'Dispatch #88 resolved', 'Accident near MG Road · 1.2 km', BadgeState.resolved, 'closed'),
        _buildActivityRow(context, '09:31', 'Dispatch #85 rejected', 'SOS at Brigade Road · busy status', BadgeState.passed, 'passed'),
        _buildActivityRow(context, '08:41', 'Patrol started', 'Location: 12.9716°N 77.5946°E', BadgeState.online, 'online'),
      ],
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
          child: OutlinedPrimaryButton(
            label: '⊕ Report Incident',
            onPressed: () => _showReportIncidentSheet(context, ref),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedPrimaryButton(
            label: '📍 Share Location',
            onPressed: () => _showShareLocationSheet(context),
          ),
        ),
      ],
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
                  Text('⊕ REPORT INCIDENT', style: AppTheme.monoMd.copyWith(color: kAccentGreen)),
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
                        final dio = ref.read(dioProvider);
                        final formData = FormData.fromMap({
                          'latitude': 12.8785,
                          'longitude': 80.0850,
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
              Text('📍 CURRENT COORDINATES', style: AppTheme.monoMd.copyWith(color: kAccentBlue)),
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

class WeeklyStatPoint {
  final String dayLabel;
  final int dispatches;
  final double avgResponseMins;
  final double avgDistanceKm;
  final bool isToday;

  const WeeklyStatPoint({
    required this.dayLabel,
    required this.dispatches,
    required this.avgResponseMins,
    required this.avgDistanceKm,
    required this.isToday,
  });
}

class WeeklyStatsPanel extends StatefulWidget {
  const WeeklyStatsPanel({super.key});
  @override
  State<WeeklyStatsPanel> createState() => _WeeklyStatsPanelState();
}

class _WeeklyStatsPanelState extends State<WeeklyStatsPanel>
    with SingleTickerProviderStateMixin {
  
  // Hardcoded weekly mock data (7 days Mon-Sun)
  final List<WeeklyStatPoint> _weekData = [
    WeeklyStatPoint(dayLabel: 'Mon', dispatches: 4, avgResponseMins: 12.5, avgDistanceKm: 2.3, isToday: false),
    WeeklyStatPoint(dayLabel: 'Tue', dispatches: 6, avgResponseMins: 9.8, avgDistanceKm: 3.1, isToday: false),
    WeeklyStatPoint(dayLabel: 'Wed', dispatches: 7, avgResponseMins: 8.2, avgDistanceKm: 4.2, isToday: false),
    WeeklyStatPoint(dayLabel: 'Thu', dispatches: 3, avgResponseMins: 14.1, avgDistanceKm: 1.9, isToday: false),
    WeeklyStatPoint(dayLabel: 'Fri', dispatches: 5, avgResponseMins: 10.3, avgDistanceKm: 2.8, isToday: false),
    WeeklyStatPoint(dayLabel: 'Sat', dispatches: 2, avgResponseMins: 16.0, avgDistanceKm: 1.4, isToday: false),
    WeeklyStatPoint(dayLabel: 'Sun', dispatches: 4, avgResponseMins: 11.7, avgDistanceKm: 2.6, isToday: true),
  ];

  int _selectedDayIndex = 6; // defaults to today (Sunday)
  late AnimationController _barAnimCtrl;
  late Animation<double> _barAnim;

  @override
  void initState() {
    super.initState();
    _barAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _barAnim = CurvedAnimation(parent: _barAnimCtrl, curve: Curves.easeOutCubic);
    _barAnimCtrl.forward();
  }

  @override
  void dispose() {
    _barAnimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = _weekData[_selectedDayIndex];
    final maxDispatches = _weekData.map((d) => d.dispatches).reduce(max).toDouble();
    final totalDispatches = _weekData.fold(0, (sum, d) => sum + d.dispatches);
    final avgResp = _weekData.fold(0.0, (sum, d) => sum + d.avgResponseMins) / 7;
    final avgDist = _weekData.fold(0.0, (sum, d) => sum + d.avgDistanceKm) / 7;
    final resolvedRate = 91; // mock
    final bestDay = _weekData.reduce((a, b) => a.dispatches >= b.dispatches ? a : b);
    final fastestDay = _weekData.reduce((a, b) => a.avgResponseMins <= b.avgResponseMins ? a : b);
    final furthestDay = _weekData.reduce((a, b) => a.avgDistanceKm >= b.avgDistanceKm ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionHeader(title: 'WEEKLY PERFORMANCE'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kAccentBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('May 19–25', style: TextStyle(color: kAccentBlue, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Bar Chart + Summary Card Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Bar Chart (takes 60% of width)
            Expanded(
              flex: 6,
              child: AnimatedBuilder(
                animation: _barAnim,
                builder: (context, _) {
                  return SizedBox(
                    height: 100,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(_weekData.length, (i) {
                        final d = _weekData[i];
                        final isSelected = i == _selectedDayIndex;
                        final barHeightRatio = d.dispatches / maxDispatches;
                        final animatedHeight = barHeightRatio * 80 * _barAnim.value;
                        
                        return GestureDetector(
                          onTap: () => setState(() => _selectedDayIndex = i),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Dispatch count label (only for selected)
                              if (isSelected)
                                Text('${d.dispatches}', style: const TextStyle(color: kAccentGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              // Bar
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 22,
                                height: animatedHeight.clamp(6.0, 80.0),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: isSelected
                                        ? [kAccentGreen, kAccentGreen.withOpacity(0.6)]
                                        : (d.isToday
                                            ? [kAccentBlue, kAccentBlue.withOpacity(0.6)]
                                            : [kDarkBorder, kDarkBorder.withOpacity(0.4)]),
                                  ),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Day label
                              Text(
                                d.dayLabel,
                                style: TextStyle(
                                  color: isSelected ? kAccentGreen : (d.isToday ? kAccentBlue : kDarkMuted),
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Summary Card (takes 40% of width)
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kDarkSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kDarkBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('WEEK TOTAL', style: TextStyle(color: kDarkMuted, fontSize: 9, letterSpacing: 1)),
                    const SizedBox(height: 6),
                    _summaryRow('$totalDispatches', 'dispatches', kAccentBlue),
                    _summaryRow('${avgResp.toStringAsFixed(0)}m', 'avg response', kAccentAmber),
                    _summaryRow('${avgDist.toStringAsFixed(1)}km', 'avg distance', kAccentGreen),
                    _summaryRow('$resolvedRate%', 'resolved', kAccentGreen),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Selected Day Detail Strip
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Container(
            key: ValueKey(_selectedDayIndex),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kAccentGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kAccentGreen.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _dayDetailChip(Icons.local_police, '${selectedDay.dispatches}', 'dispatches'),
                _dayDetailChip(Icons.timer, '${selectedDay.avgResponseMins.toStringAsFixed(0)}m', 'response'),
                _dayDetailChip(Icons.route, '${selectedDay.avgDistanceKm.toStringAsFixed(1)}km', 'distance'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 4 Micro-KPI Chips Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _kpiChip('🚔', 'Best Day', '${bestDay.dayLabel} (${bestDay.dispatches})', kAccentBlue)),
            const SizedBox(width: 8),
            Expanded(child: _kpiChip('⚡', 'Fastest', '${fastestDay.avgResponseMins.toStringAsFixed(0)}m avg', kAccentAmber)),
            const SizedBox(width: 8),
            Expanded(child: _kpiChip('📍', 'Furthest', '${furthestDay.avgDistanceKm.toStringAsFixed(1)} km', kAccentGreen)),
            const SizedBox(width: 8),
            Expanded(child: _kpiChip('🏆', 'Resolved', '$resolvedRate%', kAccentGreen)),
          ],
        ),
      ],
    );
  }

  Widget _summaryRow(String value, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Flexible(child: Text(label, style: const TextStyle(color: kDarkMuted, fontSize: 9), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _dayDetailChip(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 14, color: kAccentGreen),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: kDarkMuted, fontSize: 9)),
      ],
    );
  }

  Widget _kpiChip(String emoji, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Flexible(child: Text(title, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
