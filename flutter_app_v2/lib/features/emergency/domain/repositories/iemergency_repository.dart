import '../entities/sos_status.dart';

abstract class IEmergencyRepository {
  /// Sends an SOS alert to the backend. Returns the Alert ID if successful.
  Future<int?> triggerSOS(double lat, double lng, String severity, String message);
  
  /// Polls the backend for the current status of the active SOS.
  Future<SosStatus> getAlertStatus(int alertId);
  
  /// Cancels an active SOS alert.
  Future<void> cancelSOS(int alertId, {bool timeout = false});
  
  /// Saves the active alert ID to local storage (Hive).
  Future<void> saveActiveAlertLocally(int alertId);
  
  /// Clears the active alert from local storage.
  Future<void> clearActiveAlertLocally();
  
  /// Retrieves the active alert ID if one exists.
  Future<int?> getLocallySavedAlert();
  
  /// Fallback: Sends an SMS when offline.
  Future<bool> sendOfflineSMS(double lat, double lng);
}
