import '../entities/dispatch_request.dart';

abstract class IDispatchRepository {
  /// Polls the server to see if a dispatch is currently assigned to this officer.
  Future<DispatchRequest?> pollForDispatch(int officerId);

  /// Responds to a dispatch (accept or reject).
  Future<bool> respondToDispatch(int officerId, int alertId, String action);
  
  /// Plays an emergency siren sound when a dispatch is received.
  Future<void> playSirenSound();
  
  /// Stops the emergency siren sound.
  Future<void> stopSirenSound();
}
