import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/sos_status.dart';
import '../../domain/repositories/iemergency_repository.dart';
import '../../domain/use_cases/send_sos_usecase.dart';

enum SosUiState { idle, sending, searching, onWay, here, cancelled, smsSent, noOfficers }

class EmergencyProvider extends ChangeNotifier {
  final SendSosUseCase sendSosUseCase;
  final IEmergencyRepository repository;

  EmergencyProvider(this.sendSosUseCase, this.repository) {
    _checkExistingAlert();
  }

  SosUiState _uiState = SosUiState.idle;
  SosUiState get uiState => _uiState;

  int? _activeAlertId;
  String? _policeCancelReason;
  String? _officerBadge;

  String? get policeCancelReason => _policeCancelReason;
  String? get officerBadge => _officerBadge;
  bool get isActivated => _uiState != SosUiState.idle && _uiState != SosUiState.cancelled && _uiState != SosUiState.smsSent;

  Timer? _pollingTimer;

  Future<void> _checkExistingAlert() async {
    final alertId = await repository.getLocallySavedAlert();
    if (alertId != null) {
      _activeAlertId = alertId;
      _uiState = SosUiState.searching;
      notifyListeners();
      _startPolling();
    }
  }

  Future<void> triggerSOS(double lat, double lng, bool isOnline) async {
    if (isActivated) return;

    _uiState = SosUiState.sending;
    notifyListeners();

    final alertId = await sendSosUseCase.execute(lat, lng, isOnline);

    if (alertId == null) {
      // Offline fallback succeeded
      _uiState = isOnline ? SosUiState.idle : SosUiState.smsSent;
      notifyListeners();
      return;
    }

    _activeAlertId = alertId;
    _uiState = SosUiState.searching;
    notifyListeners();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_activeAlertId == null) {
        timer.cancel();
        return;
      }

      final status = await repository.getAlertStatus(_activeAlertId!);

      if (status.status == 'error') return; // Skip tick if network drops

      if (status.isPoliceCancelled) {
        _policeCancelReason = status.cancellationReason;
        _uiState = SosUiState.cancelled;
        _clearState();
        return;
      }
      
      if (status.isNoOfficers) {
        _uiState = SosUiState.noOfficers;
        _clearState();
        return;
      }

      if (status.isResolved) {
        _uiState = SosUiState.idle;
        _clearState();
        return;
      }

      if (status.isDispatched) {
        _officerBadge = status.officerBadge;
        if (status.officerDistanceKm != null && status.officerDistanceKm! <= 0.2) {
          _uiState = SosUiState.here;
        } else {
          _uiState = SosUiState.onWay;
        }
      } else {
        _uiState = SosUiState.searching;
      }
      
      notifyListeners();
    });
  }

  Future<void> cancelSOS() async {
    if (_activeAlertId != null) {
      await repository.cancelSOS(_activeAlertId!);
    }
    _uiState = SosUiState.idle;
    _clearState();
  }

  void _clearState() {
    _activeAlertId = null;
    _pollingTimer?.cancel();
    repository.clearActiveAlertLocally();
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
