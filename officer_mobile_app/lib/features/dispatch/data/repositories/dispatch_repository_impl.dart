import 'package:audioplayers/audioplayers.dart';
import '../../../../services/api_service.dart';
import '../../domain/entities/dispatch_request.dart';
import '../../domain/repositories/idispatch_repository.dart';

class DispatchRepositoryImpl implements IDispatchRepository {
  final ApiService apiService;
  final AudioPlayer _audioPlayer = AudioPlayer();

  DispatchRepositoryImpl(this.apiService);

  @override
  Future<DispatchRequest?> pollForDispatch(int officerId) async {
    final response = await apiService.pollDispatch(officerId);
    
    if (response != null && response['has_dispatch'] == true) {
      final dispatchData = response['dispatch'];
      return DispatchRequest(
        alertId: dispatchData['alert_id'],
        latitude: dispatchData['latitude'],
        longitude: dispatchData['longitude'],
        severity: dispatchData['severity'],
        distanceKm: (dispatchData['distance_km'] as num).toDouble(),
        etaMins: dispatchData['eta_mins'],
        message: dispatchData['message'],
      );
    }
    return null;
  }

  @override
  Future<bool> respondToDispatch(int officerId, int alertId, String action) async {
    final result = await apiService.respondToDispatch(officerId, alertId, action);
    return result['status'] == 'accepted' || result['status'] == 'reject' || result['status'] == 'missed';
  }

  @override
  Future<void> playSirenSound() async {
    try {
      if (_audioPlayer.state != PlayerState.playing) {
        await _audioPlayer.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer.play(AssetSource('sounds/police_siren.mp3'));
      }
    } catch (e) {
      // Audio failed to play
    }
  }

  @override
  Future<void> stopSirenSound() async {
    await _audioPlayer.stop();
  }
}
