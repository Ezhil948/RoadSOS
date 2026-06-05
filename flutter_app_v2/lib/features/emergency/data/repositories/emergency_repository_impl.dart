import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../services/api_service.dart';
import '../../domain/entities/sos_status.dart';
import '../../domain/repositories/iemergency_repository.dart';

class EmergencyRepositoryImpl implements IEmergencyRepository {
  final ApiService apiService;

  EmergencyRepositoryImpl(this.apiService);

  @override
  Future<int?> triggerSOS(double lat, double lng, String severity, String message) async {
    final result = await apiService.sendSOSAlert(
      latitude: lat,
      longitude: lng,
      severity: severity,
      message: message,
    );

    if (result['status'] != 'error') {
      final alertId = result['alert_id'];
      return alertId is int ? alertId : int.tryParse(alertId.toString());
    }
    return null;
  }

  @override
  Future<SosStatus> getAlertStatus(int alertId) async {
    final res = await apiService.getAlertStatus(alertId);
    
    if (res['status'] == 'error') {
      return SosStatus(status: 'error', isDispatched: false);
    }

    double? dist;
    String? badge;
    if (res['is_dispatched'] == true && res['officer'] != null) {
      dist = (res['officer']['distance_km'] as num?)?.toDouble();
      badge = res['officer']['badge']?.toString();
    }

    return SosStatus(
      alertId: alertId,
      status: res['status']?.toString() ?? 'unknown',
      isDispatched: res['is_dispatched'] == true,
      officerBadge: badge,
      officerDistanceKm: dist,
      cancellationReason: res['cancellation_reason']?.toString(),
    );
  }

  @override
  Future<void> cancelSOS(int alertId, {bool timeout = false}) async {
    await apiService.cancelSosAlert(alertId, reason: timeout ? 'timeout' : null);
    await clearActiveAlertLocally();
  }

  @override
  Future<void> saveActiveAlertLocally(int alertId) async {
    final box = Hive.box('settings');
    await box.put('last_sos_id', alertId);
    await box.put('last_sos_time', DateTime.now().toIso8601String());
  }

  @override
  Future<void> clearActiveAlertLocally() async {
    final box = Hive.box('settings');
    await box.delete('last_sos_id');
  }

  @override
  Future<int?> getLocallySavedAlert() async {
    final box = Hive.box('settings');
    final lastSosIdStr = box.get('last_sos_id');
    if (lastSosIdStr != null) {
      return int.tryParse(lastSosIdStr.toString());
    }
    return null;
  }

  @override
  Future<bool> sendOfflineSMS(double lat, double lng) async {
    final message = "EMERGENCY SOS: I need immediate assistance at my location: https://www.google.com/maps/search/?api=1&query=$lat,$lng";
    final uri = Uri.parse("sms:100?body=${Uri.encodeComponent(message)}");
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    return false;
  }
}
