import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';

class AccidentReportScreen extends StatefulWidget {
  const AccidentReportScreen({super.key});
  @override
  State<AccidentReportScreen> createState() => _AccidentReportScreenState();
}

class _AccidentReportScreenState extends State<AccidentReportScreen> {
  final _descController = TextEditingController();
  String _severity = 'moderate';
  int _casualties = 0;
  File? _selectedImage;
  bool _submitting = false;
  String? _aiAnalysis;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera, imageQuality: 70, maxWidth: 1280);
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
      // POST to /api/v1/ai/analyze
      final response = await api.analyzeAccidentImage(b64);
      final severity = response['severity_estimate'] ?? 'unknown';
      final objects = (response['detected_objects'] as List?)?.join(', ') ?? 'vehicles';
      setState(() => _aiAnalysis =
          '✅ AI detected: $objects. Severity: $severity. '
          '${response['recommendations']?.first ?? ''}');
    } catch (e) {
      setState(() => _aiAnalysis = 'AI analysis unavailable offline');
    }
  }

  Future<void> _submitReport() async {
    final loc = context.read<LocationService>();
    if (loc.currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Getting your location...')));
      bool granted = await loc.requestPermission();
      if (granted) {
        await loc.getCurrentLocation();
      }
      if (loc.currentPosition == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location is required to report an accident.'), backgroundColor: Colors.red));
        }
        return;
      }
    }

    final lat = loc.currentPosition!.latitude;
    final lng = loc.currentPosition!.longitude;

    setState(() => _submitting = true);
    final api = context.read<ApiService>();
    final result = await api.sendAccidentReport(
      latitude: lat,
      longitude: lng,
      severity: _severity,
      casualties: _casualties,
      description: _descController.text.isEmpty ? null : _descController.text,
      image: _selectedImage,
    );
    setState(() => _submitting = false);

    if (!mounted) return;
    final ok = result['status'] == 'ok';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? '🚨 Report sent! Officers notified. Report #${result['report_id']}'
            : result['message'] ?? 'Report sent!'),
        backgroundColor: ok ? Colors.green : Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Report Accident',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),

          // Image capture
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, width: 2,
                  style: BorderStyle.none),
              ),
              child: _selectedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_selectedImage!, fit: BoxFit.cover,
                      width: double.infinity, cacheWidth: 400))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 48, color: isDark ? Colors.grey.shade600 : Colors.grey),
                      const SizedBox(height: 8),
                      Text('Tap to capture accident photo',
                        style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey)),
                    ],
                  ),
            ),
          ),

          if (_aiAnalysis != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.blue.shade900.withOpacity(0.4) : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.blue.shade800 : Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.smart_toy, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_aiAnalysis!,
                    style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          const Text('Severity', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'minor', label: Text('Minor')),
              ButtonSegment(value: 'moderate', label: Text('Moderate')),
              ButtonSegment(value: 'critical', label: Text('Critical')),
            ],
            selected: {_severity},
            onSelectionChanged: (s) => setState(() => _severity = s.first),
          ),

          const SizedBox(height: 20),
          const Text('Casualties (approx)', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _casualties > 0
                  ? () => setState(() => _casualties--) : null,
              ),
              Text('$_casualties',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(() => _casualties++),
              ),
            ],
          ),

          const SizedBox(height: 20),
          TextField(
            controller: _descController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'What happened? Any specific details...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _submitting
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send),
              label: Text(_submitting ? 'Sending...' : 'Submit Report'),
              onPressed: _submitting ? null : _submitReport,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
