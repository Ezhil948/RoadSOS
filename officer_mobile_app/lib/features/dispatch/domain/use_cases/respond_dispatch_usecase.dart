import '../repositories/idispatch_repository.dart';

class RespondDispatchUseCase {
  final IDispatchRepository repository;

  RespondDispatchUseCase(this.repository);

  /// Executes the business logic for responding to a dispatch.
  Future<bool> execute(int officerId, int alertId, String action) async {
    // Domain Rule: Stop the siren immediately when any action is taken (accept/reject)
    await repository.stopSirenSound();
    
    // Process the network request
    final success = await repository.respondToDispatch(officerId, alertId, action);
    
    return success;
  }
}
