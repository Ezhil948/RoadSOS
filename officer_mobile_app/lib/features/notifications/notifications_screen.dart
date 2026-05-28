import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/models/dispatch.dart';
import '../history/history_screen.dart';
import '../../widgets/components.dart';
import '../../widgets/stat_row.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import 'package:dio/dio.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<SystemNotification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('${ApiEndpoints.baseUrl}/api/v1/logs/recent');
      final List logs = res.data['logs'] ?? [];
      
      setState(() {
        _notifications = logs.map((log) {
          final date = DateTime.parse(log['at']).toLocal();
          final isToday = date.day == DateTime.now().day && date.month == DateTime.now().month;
          return SystemNotification(
            id: log['id'],
            type: _getTypeForEvent(log['event']),
            time: DateFormat('hh:mm a').format(date),
            date: isToday ? 'TODAY' : DateFormat('MMM dd').format(date).toUpperCase(),
            message: log['event'].toString().replaceAll('_', ' '),
          );
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  NotificationType _getTypeForEvent(String event) {
    if (event.contains('RESOLVED') || event.contains('ACCEPTED')) return NotificationType.success;
    if (event.contains('REJECT') || event.contains('MISSED') || event.contains('ERROR')) return NotificationType.warning;
    return NotificationType.info;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bgColor = isDark ? kDarkBg : kLightBg;
    final borderColor = isDark ? kDarkBorder : kLightBorder;
    final textColor = isDark ? kDarkText : kLightText;
    final mutedColor = isDark ? kDarkMuted : kLightMuted;

    final surfaceColor = isDark ? kDarkSurface : kLightSurface;

    // Group notifications by date
    final todayNotifs = _notifications.where((n) => n.date == 'TODAY').toList();
    final yesterdayNotifs = _notifications.where((n) => n.date == 'YESTERDAY').toList();

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'SYSTEM NOTIFICATION LOG'),
              
              Expanded(
                child: _isLoading 
                    ? const Center(child: CircularProgressIndicator()) 
                    : _notifications.isEmpty
                        ? const Center(child: Text('No recent logs'))
                        : ListView(
                            children: [
                              if (todayNotifs.isNotEmpty) ...[
                                _buildGroupHeader('TODAY', mutedColor),
                                const SizedBox(height: 12),
                                ...todayNotifs.map((n) => _buildNotificationRow(n, textColor, mutedColor, borderColor, surfaceColor)),
                                const SizedBox(height: 24),
                              ],
                              if (yesterdayNotifs.isNotEmpty) ...[
                                _buildGroupHeader('OTHER DAYS', mutedColor),
                                const SizedBox(height: 12),
                                ...yesterdayNotifs.map((n) => _buildNotificationRow(n, textColor, mutedColor, borderColor, surfaceColor)),
                              ],
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupHeader(String title, Color mutedColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(
        title,
        style: TextStyle(color: kAccentBlue, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildNotificationRow(SystemNotification notif, Color textColor, Color mutedColor, Color borderColor, Color surfaceColor) {
    IconData indicator;
    Color color;
    
    switch (notif.type) {
      case NotificationType.info:
        indicator = Icons.info_outline;
        color = kAccentBlue;
        break;
      case NotificationType.success:
        indicator = Icons.check_circle_outline;
        color = kAccentGreen;
        break;
      case NotificationType.warning:
        indicator = Icons.warning_amber_rounded;
        color = kAccentAmber;
        break;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          backgroundColor: surfaceColor,
          collapsedBackgroundColor: surfaceColor,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(indicator, color: color, size: 20),
          ),
          title: Text(
            notif.message,
            style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(notif.time, style: TextStyle(color: mutedColor, fontSize: 12)),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).brightness == Brightness.dark ? kDarkBg : kLightBg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
                  const SizedBox(height: 8),
                  Text(
                    notif.alertId != null 
                        ? 'This notification relates to Incident #${notif.alertId}. The situation was logged and handled appropriately. Check the History tab for a full map and timeline breakdown.'
                        : 'System log event. No further action is required.',
                    style: TextStyle(color: textColor, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum NotificationType { info, success, warning }

class SystemNotification {
  final int id;
  final NotificationType type;
  final String time;
  final String date;
  final String message;
  final int? alertId;

  SystemNotification({
    required this.id,
    required this.type,
    required this.time,
    required this.date,
    required this.message,
    this.alertId,
  });
}
