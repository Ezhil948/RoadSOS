import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_client.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _alerts = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('${ApiEndpoints.baseUrl}/sos/alerts');
      if (mounted) {
        setState(() {
          _alerts = response.data['alerts'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load history')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? kDarkBg : kLightBg;
    final textColor = isDark ? kDarkText : kLightText;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Alert History', style: AppTheme.monoMd),
        backgroundColor: isDark ? kDarkSurface : kLightSurface,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alerts.isEmpty
              ? const Center(child: Text('No history found.'))
              : RefreshIndicator(
                  onRefresh: _fetchHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _alerts.length,
                    itemBuilder: (context, index) {
                      final alert = _alerts[index];
                      final status = alert['status'];
                      Color statusColor = kDarkMuted;
                      if (status == 'active') statusColor = kAccentBlue;
                      if (status == 'resolved') statusColor = kAccentGreen;
                      if (status == 'cancelled' || status == 'cancelled_by_police' || status == 'cancelled_by_citizen' || status == 'false_alarm') statusColor = kAccentRed;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                iconColor: statusColor,
                                collapsedIconColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                title: Text(
                                  'Alert #${alert['id']} - ${alert['severity'].toString().toUpperCase()}', 
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: textColor),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    alert['message'] ?? 'SOS Alert', 
                                    maxLines: 1, 
                                    style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 14),
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: statusColor.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    status.toString().toUpperCase(), 
                                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                                ),
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16.0),
                                    color: isDark ? const Color(0xFF0F172A).withOpacity(0.3) : const Color(0xFFF8FAFC),
                                    width: double.infinity,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Metadata Grid
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: _InfoBlock(
                                                icon: Icons.person_rounded,
                                                label: 'Requester',
                                                value: alert['requester_name'] ?? 'Unknown Citizen',
                                                isDark: isDark,
                                              ),
                                            ),
                                            Expanded(
                                              child: _InfoBlock(
                                                icon: Icons.access_time_rounded,
                                                label: 'Timing',
                                                value: alert['alerted_at'] != null 
                                                    ? DateFormat('MMM d, y HH:mm').format(DateTime.parse(alert['alerted_at'])) 
                                                    : 'Unknown',
                                                isDark: isDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: _InfoBlock(
                                                icon: Icons.location_on_rounded,
                                                label: 'Location Data',
                                                value: '${alert['latitude']}, ${alert['longitude']}',
                                                isDark: isDark,
                                              ),
                                            ),
                                            Expanded(
                                              child: _InfoBlock(
                                                icon: Icons.phone_android_rounded,
                                                label: 'Contact',
                                                value: alert['requester_phone'] ?? 'Not provided',
                                                isDark: isDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                        
                                        // Cancellation Details
                                        if (status.toString().contains('cancel')) ...[
                                          const SizedBox(height: 16),
                                          const Divider(height: 1),
                                          const SizedBox(height: 12),
                                          Text('Cancellation Details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(Icons.cancel_rounded, size: 16, color: kAccentRed),
                                              const SizedBox(width: 8),
                                              Text('By: ${alert['cancelled_by'] ?? 'Citizen'}', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 24),
                                            child: Text('Reason: ${alert['cancellation_reason'] ?? 'Not specified'}', style: TextStyle(color: textColor, fontSize: 13)),
                                          ),
                                          if (alert['cancellation_details'] != null)
                                            Padding(
                                              padding: const EdgeInsets.only(left: 24, top: 2),
                                              child: Text('Details: ${alert['cancellation_details']}', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13)),
                                            ),
                                        ],
                                        
                                        // Attached Photos
                                        if (alert['photos'] != null && (alert['photos'] as List).isNotEmpty) ...[
                                          const SizedBox(height: 16),
                                          const Divider(height: 1),
                                          const SizedBox(height: 12),
                                          Text('Attached Photos', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            height: 120,
                                            child: ListView.builder(
                                              scrollDirection: Axis.horizontal,
                                              itemCount: (alert['photos'] as List).length,
                                              itemBuilder: (context, photoIndex) {
                                                return Container(
                                                  width: 120,
                                                  margin: const EdgeInsets.only(right: 12),
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(8),
                                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                                    image: DecorationImage(
                                                      image: NetworkImage('${ApiEndpoints.baseUrl}/static/uploads/${alert['photos'][photoIndex]}'),
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _InfoBlock({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87)),
      ],
    );
  }
}
