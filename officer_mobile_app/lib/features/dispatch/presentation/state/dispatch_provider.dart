import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/dispatch_request.dart';
import '../../domain/repositories/idispatch_repository.dart';
import '../../domain/use_cases/respond_dispatch_usecase.dart';

enum DispatchUiState { idle, polling, incoming, accepted, error }

class DispatchProvider extends ChangeNotifier {
  final IDispatchRepository repository;
  final RespondDispatchUseCase respondUseCase;

  DispatchProvider({required this.repository, required this.respondUseCase});

  DispatchUiState _uiState = DispatchUiState.idle;
  DispatchUiState get uiState => _uiState;

  DispatchRequest? _currentDispatch;
  DispatchRequest? get currentDispatch => _currentDispatch;

  Timer? _pollingTimer;
  int? _currentOfficerId;

  void startPolling(int officerId) {
    _currentOfficerId = officerId;
    _uiState = DispatchUiState.polling;
    notifyListeners();

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      final dispatch = await repository.pollForDispatch(officerId);
      
      if (dispatch != null && _uiState != DispatchUiState.incoming && _uiState != DispatchUiState.accepted) {
        _currentDispatch = dispatch;
        _uiState = DispatchUiState.incoming;
        await repository.playSirenSound();
        notifyListeners();
      }
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _uiState = DispatchUiState.idle;
    notifyListeners();
  }

  Future<void> respond(String action) async {
    if (_currentOfficerId == null || _currentDispatch == null) return;

    // Use Case handles stopping the siren and executing the response logic
    final success = await respondUseCase.execute(_currentOfficerId!, _currentDispatch!.alertId, action);

    if (success) {
      if (action == 'accept') {
        _uiState = DispatchUiState.accepted;
      } else {
        _uiState = DispatchUiState.polling; // Go back to polling if rejected
        _currentDispatch = null;
      }
    } else {
      _uiState = DispatchUiState.error;
    }
    
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
