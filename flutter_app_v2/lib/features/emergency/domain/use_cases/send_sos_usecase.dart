import '../repositories/iemergency_repository.dart';

class SendSosUseCase {
  final IEmergencyRepository repository;

  SendSosUseCase(this.repository);

  /// Executes the SOS business logic. Returns the alert ID if successful, or null if it fell back to offline SMS.
  Future<int?> execute(double lat, double lng, bool isOnline) async {
    if (!isOnline) {
      // Domain Rule: If offline, automatically fallback to SMS
      await repository.sendOfflineSMS(lat, lng);
      return null;
    }

    final alertId = await repository.triggerSOS(lat, lng, 'critical', 'Emergency SOS triggered');
    
    if (alertId != null) {
      // Domain Rule: Locally persist the active SOS so it survives app restarts
      await repository.saveActiveAlertLocally(alertId);
    }
    
    return alertId;
  }
}
