import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../widgets/components.dart';
import '../../widgets/stat_row.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedMonth = DateTime.now();       // Current month being viewed
  DateTime _selectedDay = DateTime.now();         // Currently selected day
  Map<String, List<Map<String, dynamic>>> _logsByDate = {};  // Grouped logs
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }
  
  Future<void> _fetchLogs() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('${ApiEndpoints.baseUrl}/logs/recent');
      final List logs = res.data['logs'] ?? [];
      
      final currentOfficerId = Hive.box('settings').get('officer_id', defaultValue: 1);
      
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      
      for (final log in logs) {
        final meta = log['metadata'] ?? {};
        final event = log['event'] as String? ?? '';
        
        // Include dispatch events for this officer + all system events
        final isOfficerDispatch = meta['officer_id'] == currentOfficerId && event.startsWith('DISPATCH_');
        
        if (isOfficerDispatch) {
          final date = DateTime.parse(log['at']).toLocal();
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          grouped.putIfAbsent(dateKey, () => []);
          grouped[dateKey]!.add(Map<String, dynamic>.from(log));
        }
      }
      
      if (mounted) {
        setState(() {
          _logsByDate = grouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildDayCell(int day, bool isToday, bool isSelected, bool isWeekend, Color? activityDotColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? kDarkText : kLightText;
    final mutedColor = isDark ? kDarkMuted : kLightMuted;
    
    return GestureDetector(
      onTap: () => setState(() {
        _selectedDay = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      }),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? kAccentBlue : Colors.transparent,
          shape: BoxShape.circle,
          border: isToday && !isSelected
              ? Border.all(color: kAccentBlue, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : isWeekend
                        ? mutedColor
                        : textColor,
                fontSize: 14,
                fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (activityDotColor != null)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : activityDotColor,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? kDarkText : kLightText;
    final mutedColor = isDark ? kDarkMuted : kLightMuted;
    final surfaceColor = isDark ? kDarkSurface : kLightSurface;
    final borderColor = isDark ? kDarkBorder : kLightBorder;
    
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDayWeekday = DateTime(year, month, 1).weekday; // 1=Mon, 7=Sun
    
    final today = DateTime.now();
    final isCurrentMonth = today.year == year && today.month == month;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          // Month navigation header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: textColor),
                onPressed: () => setState(() {
                  _focusedMonth = DateTime(year, month - 1);
                }),
              ),
              Text(
                DateFormat('MMMM yyyy').format(_focusedMonth).toUpperCase(),
                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              Row(
                children: [
                  // "Today" button — only show if not already viewing current month
                  if (!isCurrentMonth)
                    GestureDetector(
                      onTap: () => setState(() {
                        _focusedMonth = DateTime(today.year, today.month);
                        _selectedDay = today;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: kAccentBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kAccentBlue.withOpacity(0.3)),
                        ),
                        child: const Text('TODAY', style: TextStyle(color: kAccentBlue, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: textColor),
                    onPressed: () => setState(() {
                      _focusedMonth = DateTime(year, month + 1);
                    }),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Day-of-week headers
          Row(
            children: ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d, style: TextStyle(color: mutedColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ),
                    ))
                .toList(),
          ),
          
          const SizedBox(height: 8),
          
          // Day cells grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              final dayNumber = index - firstDayWeekday + 2;
              
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink(); // Empty space
              }
              
              final isToday = today.year == year && today.month == month && today.day == dayNumber;
              final isSelected = _selectedDay.year == year && _selectedDay.month == month && _selectedDay.day == dayNumber;
              
              final cellDate = DateTime(year, month, dayNumber);
              final isWeekend = cellDate.weekday == 6 || cellDate.weekday == 7;
              
              final dateKey = DateFormat('yyyy-MM-dd').format(cellDate);
              final dayLogs = _logsByDate[dateKey] ?? [];
              
              Color? activityColor;
              if (dayLogs.isNotEmpty) {
                bool hasRejected = dayLogs.any((l) => l['event'] == 'DISPATCH_REJECTED' || l['event'] == 'DISPATCH_MISSED');
                bool allResolved = dayLogs.every((l) => l['event'] == 'DISPATCH_RESOLVED');
                if (hasRejected) {
                  activityColor = kAccentAmber;
                } else if (allResolved) {
                  activityColor = kAccentGreen;
                } else {
                  activityColor = kAccentBlue;
                }
              }
              
              return _buildDayCell(dayNumber, isToday, isSelected, isWeekend, activityColor);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDispatchCard(Map<String, dynamic> log) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? kDarkBg : kLightBg;
    final borderColor = isDark ? kDarkBorder : kLightBorder;
    final textColor = isDark ? kDarkText : kLightText;
    final mutedColor = isDark ? kDarkMuted : kLightMuted;
    
    final event = log['event'] as String;
    final date = DateTime.parse(log['at']).toLocal();
    final meta = log['metadata'] ?? {};
    final alertId = meta['alert_id'];
    
    // Determine status color and label
    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    
    if (event == 'DISPATCH_RESOLVED') {
      statusColor = kAccentGreen;
      statusLabel = 'RESOLVED';
      statusIcon = Icons.check_circle_outline;
    } else if (event == 'DISPATCH_ACCEPTED') {
      statusColor = kAccentBlue;
      statusLabel = 'ACCEPTED';
      statusIcon = Icons.directions_car_outlined;
    } else if (event == 'DISPATCH_REJECTED') {
      statusColor = kAccentRed;
      statusLabel = 'REJECTED';
      statusIcon = Icons.close;
    } else if (event == 'DISPATCH_MISSED') {
      statusColor = kDarkMuted;
      statusLabel = 'MISSED';
      statusIcon = Icons.timer_off_outlined;
    } else {
      statusColor = kAccentBlue;
      statusLabel = event.replaceAll('DISPATCH_', '');
      statusIcon = Icons.info_outline;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left accent strip
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Status icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alert #${alertId ?? '---'}',
                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('hh:mm a').format(date),
                            style: TextStyle(color: mutedColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayDetail() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? kDarkSurface : kLightSurface;
    final borderColor = isDark ? kDarkBorder : kLightBorder;
    final textColor = isDark ? kDarkText : kLightText;
    final mutedColor = isDark ? kDarkMuted : kLightMuted;
    
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDay);
    final dayLogs = _logsByDate[dateKey] ?? [];
    final isWeekend = _selectedDay.weekday == 6 || _selectedDay.weekday == 7;
    final isPast = _selectedDay.isBefore(DateTime.now().subtract(const Duration(days: 1)));
    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDay) == DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEEE, dd MMMM').format(_selectedDay).toUpperCase(),
                style: TextStyle(color: kAccentBlue, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              // Working day / Off day badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isWeekend
                      ? kAccentAmber.withOpacity(0.1)
                      : kAccentGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isWeekend
                        ? kAccentAmber.withOpacity(0.3)
                        : kAccentGreen.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  isWeekend ? 'OFF DAY' : 'WORKING DAY',
                  style: TextStyle(
                    color: isWeekend ? kAccentAmber : kAccentGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Day content
          if (dayLogs.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      isPast ? Icons.check_circle_outline : Icons.event_note_outlined,
                      color: mutedColor,
                      size: 36,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isPast
                          ? 'No dispatches recorded'
                          : isToday
                              ? 'No dispatches today yet'
                              : 'Scheduled working day',
                      style: TextStyle(color: mutedColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ...dayLogs.map((log) => _buildDispatchCard(log)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? kDarkBg : kLightBg;
    
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchLogs,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'DUTY CALENDAR'),
                      _buildCalendarGrid(),
                      const SizedBox(height: 16),
                      _buildDayDetail(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
