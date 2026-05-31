import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'api_service.dart';
import '../models/offline_report.dart';

class OfflineSyncService extends ChangeNotifier {
  final ApiService _apiService;
  final Connectivity _connectivity = Connectivity();
  
  List<OfflineReport> _pendingReports = [];
  bool _isSyncing = false;
  bool _initialized = false;

  List<OfflineReport> get pendingReports => _pendingReports;
  bool get isSyncing => _isSyncing;
  int get queueCount => _pendingReports.length;
  bool get hasPendingReports => _pendingReports.isNotEmpty;

  OfflineSyncService({required ApiService apiService}) : _apiService = apiService {
    _init();
  }

  Future<void> _init() async {
    if (_initialized) return;
    await loadPendingReports();
    
    // Listen to connectivity changes to trigger automatic sync
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final hasConnection = results.any((result) => result != ConnectivityResult.none);
      if (hasConnection && hasPendingReports) {
        syncPendingReports();
      }
    });

    _initialized = true;
    
    // Initial sync check
    final status = await _connectivity.checkConnectivity();
    if (status.any((result) => result != ConnectivityResult.none) && hasPendingReports) {
      syncPendingReports();
    }
  }

  Future<void> loadPendingReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reportsJson = prefs.getStringList('offline_reports_queue') ?? [];
      
      _pendingReports = reportsJson.map((jsonStr) {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        return OfflineReport.fromJson(data);
      }).toList();
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading pending reports: $e');
    }
  }

  Future<void> _savePendingReportsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reportsJson = _pendingReports.map((report) => jsonEncode(report.toJson())).toList();
      await prefs.setStringList('offline_reports_queue', reportsJson);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving pending reports: $e');
    }
  }

  Future<void> saveReportOffline({
    required double latitude,
    required double longitude,
    required String severity,
    required int casualties,
    String? description,
    File? image,
  }) async {
    final String reportId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
    String? persistentImagePath;

    try {
      if (image != null && await image.exists()) {
        final appDir = await getApplicationDocumentsDirectory();
        final offlineImagesDir = Directory('${appDir.path}/offline_reports');
        if (!await offlineImagesDir.exists()) {
          await offlineImagesDir.create(recursive: true);
        }
        
        final extension = image.path.split('.').last;
        final fileName = 'img_$reportId.$extension';
        final savedImage = await image.copy('${offlineImagesDir.path}/$fileName');
        persistentImagePath = savedImage.path;
      }
    } catch (e) {
      debugPrint('Error copying image persistently: $e');
    }

    final newReport = OfflineReport(
      id: reportId,
      latitude: latitude,
      longitude: longitude,
      severity: severity,
      casualties: casualties,
      description: description,
      imagePath: persistentImagePath,
      timestamp: DateTime.now().toIso8601String(),
    );

    _pendingReports.add(newReport);
    await _savePendingReportsToStorage();
  }

  Future<void> syncPendingReports() async {
    if (_isSyncing || _pendingReports.isEmpty) return;

    _isSyncing = true;
    notifyListeners();

    final List<OfflineReport> succeededReports = [];

    for (final report in List<OfflineReport>.from(_pendingReports)) {
      File? imageFile;
      if (report.imagePath != null) {
        final file = File(report.imagePath!);
        if (await file.exists()) {
          imageFile = file;
        }
      }

      try {
        final result = await _apiService.sendAccidentReport(
          latitude: report.latitude,
          longitude: report.longitude,
          severity: report.severity,
          casualties: report.casualties,
          description: report.description,
          image: imageFile,
        );

        if (result['status'] != 'error') {
          // Success! Mark for removal and clean up image file
          succeededReports.add(report);
          if (imageFile != null) {
            try {
              await imageFile.delete();
            } catch (e) {
              debugPrint('Error deleting synced report image: $e');
            }
          }
        } else {
          // If we fail on a specific report due to server logic (not network), we might continue or stop
          // But to be safe, if we hit a network issue, we abort the batch sync
          final message = result['message']?.toString() ?? '';
          if (message.contains('DioException') || message.contains('SocketException') || message.contains('Failed host lookup')) {
            debugPrint('Aborting sync batch due to network connection issues.');
            break;
          }
        }
      } catch (e) {
        debugPrint('Error syncing offline report: $e');
        break; // Network or unexpected error, stop the batch sync
      }
    }

    if (succeededReports.isNotEmpty) {
      _pendingReports.removeWhere((r) => succeededReports.contains(r));
      await _savePendingReportsToStorage();
    }

    _isSyncing = false;
    notifyListeners();
  }
}
