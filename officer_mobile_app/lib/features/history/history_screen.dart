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

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: isDark ? kDarkSurface : kLightSurface,
                        child: ExpansionTile(
                          title: Text('Alert #${alert['id']} - ${alert['severity'].toString().toUpperCase()}', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                          subtitle: Text(alert['message'] ?? 'SOS Alert', maxLines: 1),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(status.toString().toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Time: ${alert['alerted_at'] != null ? DateFormat('MMM d, y HH:mm').format(DateTime.parse(alert['alerted_at'])) : 'Unknown'}'),
                                  const SizedBox(height: 8),
                                  if (status.toString().contains('cancel')) ...[
                                    Text('Cancelled By: ${alert['cancelled_by'] ?? 'citizen'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text('Reason: ${alert['cancellation_reason'] ?? 'Not specified'}'),
                                    if (alert['cancellation_details'] != null)
                                      Text('Details: ${alert['cancellation_details']}'),
                                    const SizedBox(height: 8),
                                  ],
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
