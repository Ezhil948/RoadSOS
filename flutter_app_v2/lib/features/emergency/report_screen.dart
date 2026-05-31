import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../services/location_service.dart';
import '../../services/api_service.dart';
import '../../services/offline_sync_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _descController = TextEditingController();
  String _severity = 'moderate';
  int _casualties = 0;
  File? _selectedImage;
  bool _submitting = false;
  String? _aiAnalysis;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1280);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
      await _analyzeImage(File(picked.path));
    }
  }

  Future<void> _analyzeImage(File img) async {
    setState(() => _aiAnalysis = 'Analyzing image...');
    try {
      final api = context.read<ApiService>();
      final bytes = await img.readAsBytes();
      final b64 = base64Encode(bytes);
      final response = await api.analyzeAccidentImage(b64);
      final severity = response['severity_estimate'] ?? 'unknown';
      final objects = (response['detected_objects'] as List?)?.join(', ') ?? 'vehicles';
      
      setState(() {
        _aiAnalysis = '✅ AI detected: $objects. Severity: $severity.\n${response['recommendations']?.first ?? ''}';
        if (['minor', 'moderate', 'critical'].contains(severity.toString().toLowerCase())) {
          _severity = severity.toString().toLowerCase();
        }
      });
    } catch (e) {
      setState(() => _aiAnalysis = 'AI analysis unavailable');
    }
  }

  Future<void> _submitReport() async {
    final loc = context.read<LocationService>();
    if (!loc.hasPermission || loc.currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location is required.'), backgroundColor: AppTheme.primaryRed));
      return;
    }

    setState(() => _submitting = true);
    final api = context.read<ApiService>();
    final result = await api.sendAccidentReport(
      latitude: loc.currentPosition!.latitude,
      longitude: loc.currentPosition!.longitude,
      severity: _severity,
      casualties: _casualties,
      description: _descController.text.isEmpty ? null : _descController.text,
      image: _selectedImage,
    );
    setState(() => _submitting = false);

    if (!mounted) return;
    final ok = result['status'] != 'error';
    
    final isNetworkError = !ok && (
      result['message'].toString().contains('DioException') ||
      result['message'].toString().contains('SocketException') ||
      result['message'].toString().contains('Failed host lookup') ||
      result['message'].toString().contains('connection error')
    );

    if (isNetworkError) {
      final offlineService = context.read<OfflineSyncService>();
      await offlineService.saveReportOffline(
        latitude: loc.currentPosition!.latitude,
        longitude: loc.currentPosition!.longitude,
        severity: _severity,
        casualties: _casualties,
        description: _descController.text.isEmpty ? null : _descController.text,
        image: _selectedImage,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Offline! Report saved locally. We\'ll upload it automatically when connection is restored.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.accentAmber,
          duration: Duration(seconds: 5),
        ),
      );
      Navigator.pop(context);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '🚨 Report sent! Officers notified. Report #${result['report_id']}' : result['message'] ?? 'Error'),
        backgroundColor: ok ? AppTheme.accentGreen : AppTheme.accentAmber,
      ),
    );
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Accident', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Capture
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderDark, width: 2),
                ),
                child: _selectedImage != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(_selectedImage!, fit: BoxFit.cover)),
                          if (_aiAnalysis == 'Analyzing image...')
                            Container(
                              color: Colors.black54,
                              child: const Center(child: CircularProgressIndicator(color: AppTheme.accentAmber)),
                            ),
                        ],
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_rounded, size: 48, color: AppTheme.borderDark),
                          SizedBox(height: 8),
                          Text('Tap to capture accident photo', style: TextStyle(color: AppTheme.textMuted)),
                        ],
                      ),
              ),
            ),

            if (_aiAnalysis != null && _aiAnalysis != 'Analyzing image...') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A2030),
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(left: BorderSide(color: AppTheme.accentTeal, width: 3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.smart_toy_rounded, color: AppTheme.accentTeal),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_aiAnalysis!, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary))),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            const Text('Severity', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildSeverityPill('minor', 'Minor', AppTheme.accentGreen),
                const SizedBox(width: 8),
                _buildSeverityPill('moderate', 'Moderate', AppTheme.accentAmber),
                const SizedBox(width: 8),
                _buildSeverityPill('critical', 'Critical', AppTheme.primaryRed),
              ],
            ),

            const SizedBox(height: 24),
            const Text('Casualties (approx)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: AppTheme.textMuted),
                  onPressed: _casualties > 0 ? () => setState(() => _casualties--) : null,
                ),
                Text('$_casualties', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppTheme.textMuted),
                  onPressed: () => setState(() => _casualties++),
                ),
              ],
            ),

            const SizedBox(height: 24),
            TextField(
              controller: _descController,
              maxLines: 4,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'What happened? Any specific details...',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                fillColor: AppTheme.surfaceElevated,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.accentBlue)),
              ),
            ),

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _submitting ? null : _submitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                minimumSize: const Size.fromHeight(56),
              ),
              child: _submitting 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityPill(String value, String label, Color color) {
    final isSelected = _severity == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _severity = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: isSelected ? color : AppTheme.borderDark),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textMuted,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
