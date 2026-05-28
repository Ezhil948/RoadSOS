import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/models/dispatch.dart';
import '../../widgets/components.dart';
import '../../widgets/git_badge.dart';
import '../../widgets/stat_row.dart';

// ── Indian Public Holidays 2025-2026 ─────────────────────────────────────────
const List<Map<String, dynamic>> kIndianHolidays = [
  {'date': '2025-01-14', 'name': 'Makar Sankranti'},
  {'date': '2025-01-26', 'name': 'Republic Day'},
  {'date': '2025-03-14', 'name': 'Holi'},
  {'date': '2025-04-14', 'name': 'Dr. Ambedkar Jayanti'},
  {'date': '2025-04-18', 'name': 'Good Friday'},
  {'date': '2025-05-01', 'name': 'Maharashtra/Karnataka Day'},
  {'date': '2025-06-07', 'name': 'Eid ul-Adha'},
  {'date': '2025-08-15', 'name': 'Independence Day'},
  {'date': '2025-08-16', 'name': 'Janmashtami'},
  {'date': '2025-09-29', 'name': 'Dussehra'},
  {'date': '2025-10-02', 'name': 'Gandhi Jayanti'},
  {'date': '2025-10-20', 'name': 'Diwali (Lakshmi Puja)'},
  {'date': '2025-10-21', 'name': 'Diwali (Govardhan Puja)'},
  {'date': '2025-11-05', 'name': 'Guru Nanak Jayanti'},
  {'date': '2025-12-25', 'name': 'Christmas Day'},
  {'date': '2026-01-14', 'name': 'Makar Sankranti'},
  {'date': '2026-01-26', 'name': 'Republic Day'},
  {'date': '2026-03-03', 'name': 'Holi'},
  {'date': '2026-04-03', 'name': 'Good Friday'},
  {'date': '2026-04-14', 'name': 'Dr. Ambedkar Jayanti'},
  {'date': '2026-05-01', 'name': 'Maharashtra/Karnataka Day'},
  {'date': '2026-08-15', 'name': 'Independence Day'},
  {'date': '2026-10-02', 'name': 'Gandhi Jayanti'},
  {'date': '2026-12-25', 'name': 'Christmas Day'},
];

// ── Mock Day History Data ─────────────────────────────────────────────────────
// In production, call: GET /officers/{id}/history?date=YYYY-MM-DD
Map<String, List<DayEvent>> kMockDayEvents = {
  '2025-05-21': const [
    DayEvent(time: '08:41', type: EventType.patrol, title: 'Patrol started', sub: '12.9716°N 77.5946°E'),
    DayEvent(time: '09:31', type: EventType.dispatch, title: 'Dispatch #85 rejected', sub: 'SOS at Brigade Road · busy status', status: 'rejected'),
    DayEvent(time: '10:42', type: EventType.dispatch, title: 'Dispatch #88 resolved', sub: 'Accident near MG Road · 1.2 km', status: 'resolved'),
    DayEvent(time: '14:00', type: EventType.break_, title: 'Break started', sub: 'Duration: 45 min'),
    DayEvent(time: '18:00', type: EventType.shiftEnd, title: 'Shift ended', sub: '10 hrs 12 dispatches'),
  ],
  '2025-05-20': const [
    DayEvent(time: '07:00', type: EventType.patrol, title: 'Patrol started', sub: 'Zone A coverage'),
    DayEvent(time: '09:12', type: EventType.dispatch, title: 'Dispatch #83 resolved', sub: 'Vehicle breakdown · NH44', status: 'resolved'),
    DayEvent(time: '12:30', type: EventType.break_, title: 'Break started', sub: 'Duration: 30 min'),
    DayEvent(time: '17:00', type: EventType.shiftEnd, title: 'Shift ended', sub: '10 hrs 8 dispatches'),
  ],
};

enum EventType { dispatch, patrol, break_, shiftEnd, incident }

class DayEvent {
  final String time;
  final EventType type;
  final String title;
  final String sub;
  final String? status; // 'resolved', 'rejected', 'false_alarm'

  const DayEvent({
    required this.time,
    required this.type,
    required this.title,
    required this.sub,
    this.status,
  });
}

// ── Main Screen ───────────────────────────────────────────────────────────────
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;

  // Parse holiday dates to a fast Set<String>
  final Set<String> _holidayDates = Set.from(
    kIndianHolidays.map((h) => h['date'] as String),
  );

  bool _isHoliday(DateTime date) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    return _holidayDates.contains(key);
  }

  String? _holidayName(DateTime date) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    final match = kIndianHolidays.firstWhere(
      (h) => h['date'] == key,
      orElse: () => {},
    );
    return match.isEmpty ? null : match['name'] as String;
  }

  bool _isWorkingDay(DateTime date) {
    // Mon–Sat are working days (Sun = off), unless it's a holiday
    return date.weekday != DateTime.sunday && !_isHoliday(date);
  }

  bool _hasEvents(DateTime date) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    return kMockDayEvents.containsKey(key);
  }


  void _goToPreviousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  void _onDateTapped(DateTime date) {
    setState(() => _selectedDate = date);
    _showDayDetailSheet(date);
  }

  void _showDayDetailSheet(DateTime date) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final key = DateFormat('yyyy-MM-dd').format(date);
    final events = kMockDayEvents[key] ?? [];
    final holidayName = _holidayName(date);
    final titleDate = DateFormat('EEEE, d MMMM yyyy').format(date);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? kDarkSurface : kLightSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? kDarkBorder : kLightBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Title Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titleDate,
                                style: TextStyle(
                                  color: isDark ? kDarkText : kLightText,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (holidayName != null) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6B6B).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.celebration, size: 12, color: Color(0xFFFF6B6B)),
                                      const SizedBox(width: 4),
                                      Text(holidayName, style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (events.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: kAccentBlue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${events.where((e) => e.type == EventType.dispatch).length} dispatches',
                              style: const TextStyle(color: kAccentBlue, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Event Timeline or Empty State
                  Expanded(
                    child: events.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_available, size: 48, color: isDark ? kDarkMuted : kLightMuted),
                                const SizedBox(height: 12),
                                Text(
                                  holidayName != null ? 'Holiday — No shift scheduled' : 'No activity recorded for this day',
                                  style: TextStyle(color: isDark ? kDarkMuted : kLightMuted, fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            itemCount: events.length,
                            itemBuilder: (context, index) {
                              final event = events[index];
                              final isLast = index == events.length - 1;
                              return _buildTimelineEvent(event, isLast, isDark);
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTimelineEvent(DayEvent event, bool isLast, bool isDark) {
    Color dotColor;
    IconData eventIcon;

    switch (event.type) {
      case EventType.dispatch:
        dotColor = event.status == 'resolved' ? kAccentGreen : event.status == 'rejected' ? kDarkMuted : kAccentAmber;
        eventIcon = Icons.local_police;
        break;
      case EventType.patrol:
        dotColor = kAccentBlue;
        eventIcon = Icons.directions_walk;
        break;
      case EventType.break_:
        dotColor = kAccentAmber;
        eventIcon = Icons.coffee;
        break;
      case EventType.shiftEnd:
        dotColor = kDarkMuted;
        eventIcon = Icons.logout;
        break;
      case EventType.incident:
        dotColor = kAccentRed;
        eventIcon = Icons.warning_amber_rounded;
        break;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline spine
          Column(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: dotColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: dotColor, width: 2),
                ),
                child: Icon(eventIcon, size: 14, color: dotColor),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: isDark ? kDarkBorder : kLightBorder),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Event card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? kDarkBg : kLightBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? kDarkBorder : kLightBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event.title, style: TextStyle(color: isDark ? kDarkText : kLightText, fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(event.sub, style: TextStyle(color: isDark ? kDarkMuted : kLightMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    // Time chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? kDarkSurface : kLightSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(event.time, style: AppTheme.monoSm.copyWith(color: isDark ? kDarkSubtext : kLightSubtext)),
                    ),
                    // Status badge (if dispatch)
                    if (event.status != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: dotColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          event.status!.toUpperCase().replaceAll('_', ' '),
                          style: TextStyle(color: dotColor, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Calendar Build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? kDarkBg : kLightBg;
    final surfaceColor = isDark ? kDarkSurface : kLightSurface;
    final borderColor = isDark ? kDarkBorder : kLightBorder;
    final textColor = isDark ? kDarkText : kLightText;
    final mutedColor = isDark ? kDarkMuted : kLightMuted;
    final now = DateTime.now();

    // Build calendar grid for _focusedMonth
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    // weekday: Mon=1 ... Sun=7. We want Mon as first column (index 0).
    int startWeekday = firstDayOfMonth.weekday - 1; // 0 = Mon, 6 = Sun

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Calendar Header ─────────────────────────────────────────────
            Container(
              color: surfaceColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // Month navigation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        color: textColor,
                        onPressed: _goToPreviousMonth,
                      ),
                      Column(
                        children: [
                          Text(
                            DateFormat('MMMM yyyy').format(_focusedMonth),
                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          // Legend row
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _legendDot(kAccentBlue, 'Today'),
                              const SizedBox(width: 12),
                              _legendDot(const Color(0xFFFF6B6B), 'Holiday'),
                              const SizedBox(width: 12),
                              _legendDot(kAccentGreen, 'Has events'),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        color: textColor,
                        onPressed: _goToNextMonth,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Day-of-week labels (Mon–Sun)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) {
                      return SizedBox(
                        width: 36,
                        child: Text(d, textAlign: TextAlign.center, style: const TextStyle(color: kDarkMuted, fontWeight: FontWeight.bold, fontSize: 12)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  // Calendar Grid
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                        left: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                      ),
                    ),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: startWeekday + daysInMonth,
                      itemBuilder: (context, index) {
                        final gridBorderColor = isDark ? Colors.white10 : Colors.black12;
                        if (index < startWeekday) {
                          return Container(
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: gridBorderColor),
                                bottom: BorderSide(color: gridBorderColor),
                              ),
                            ),
                          );
                        }

                        final day = index - startWeekday + 1;
                        final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
                        final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
                        final isSelected = _selectedDate != null &&
                            _selectedDate!.year == date.year &&
                            _selectedDate!.month == date.month &&
                            _selectedDate!.day == date.day;
                        final isHoliday = _isHoliday(date);

                        final isSunday = date.weekday == DateTime.sunday;
                        final hasEvents = _hasEvents(date);

                        // ── Color logic (mirrors Google Calendar) ──
                        Color numColor;
                        Color bgCell;

                        if (isSelected) {
                          bgCell = kAccentBlue;
                          numColor = Colors.white;
                        } else if (isToday) {
                          bgCell = kAccentBlue.withOpacity(0.18);
                          numColor = kAccentBlue;
                        } else if (isHoliday) {
                          bgCell = const Color(0xFFFF6B6B).withOpacity(0.1);
                          numColor = const Color(0xFFFF6B6B);
                        } else if (isSunday) {
                          bgCell = Colors.transparent;
                          numColor = const Color(0xFFFF6B6B).withOpacity(0.7);
                        } else {
                          bgCell = Colors.transparent;
                          numColor = textColor;
                        }

                        return GestureDetector(
                          onTap: () => _onDateTapped(date),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: bgCell,
                              border: Border(
                                right: BorderSide(color: gridBorderColor),
                                bottom: BorderSide(color: gridBorderColor),
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Text(
                                  '$day',
                                  style: TextStyle(
                                    color: numColor,
                                    fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                                // Green dot indicator for days with events
                                if (hasEvents && !isSelected)
                                  Positioned(
                                    bottom: 4,
                                    child: Container(
                                      width: 4, height: 4,
                                      decoration: const BoxDecoration(color: kAccentGreen, shape: BoxShape.circle),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Divider with holiday name tooltip for selected date
            if (_selectedDate != null && _holidayName(_selectedDate!) != null)
              Container(
                color: const Color(0xFFFF6B6B).withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.celebration, size: 14, color: Color(0xFFFF6B6B)),
                    const SizedBox(width: 8),
                    Text(
                      '${_holidayName(_selectedDate!)} — Public Holiday',
                      style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

            // ── Activity Stream (bottom section) ───────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SectionHeader(title: 'RECENT ACTIVITY'),
                  Text('Tap a date for full details', style: TextStyle(color: mutedColor, fontSize: 11)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: kMockDayEvents.length,
                itemBuilder: (context, index) {
                  final entry = kMockDayEvents.entries.elementAt(index);
                  final dateStr = entry.key;
                  final events = entry.value;
                  final date = DateTime.parse(dateStr);
                  final dispatchCount = events.where((e) => e.type == EventType.dispatch).length;
                  final resolvedCount = events.where((e) => e.type == EventType.dispatch && e.status == 'resolved').length;
                  final isHoliday = _isHoliday(date);

                  return AnimatedTap(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _onDateTapped(date),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          // Date column (like Google Calendar)
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: kAccentBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(DateFormat('dd').format(date), style: const TextStyle(color: kAccentBlue, fontWeight: FontWeight.bold, fontSize: 18, height: 1)),
                                Text(DateFormat('MMM').format(date).toUpperCase(), style: const TextStyle(color: kAccentBlue, fontSize: 9)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(DateFormat('EEEE').format(date), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                    if (isHoliday) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: const Color(0xFFFF6B6B).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                        child: const Text('Holiday', style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('$dispatchCount dispatches · $resolvedCount resolved', style: TextStyle(color: mutedColor, fontSize: 12)),
                              ],
                            ),
                          ),
                          // Arrow
                          Icon(Icons.chevron_right, color: mutedColor, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: kDarkMuted, fontSize: 10)),
      ],
    );
  }
}
