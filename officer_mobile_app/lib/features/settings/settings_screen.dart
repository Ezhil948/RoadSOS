import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../widgets/components.dart';
import '../../widgets/stat_row.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late Box _settingsBox;
  
  // Local settings variables
  String _mapStyle = 'Standard';
  bool _pushEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String _alertSound = 'Standard Tone';
  double _pingInterval = 3.0; // seconds
  String _autoOfflineIdle = 'Never';
  double _autoRejectSeconds = 30.0;
  String _navApp = 'Google Maps';
  String _language = 'English';
  late TextEditingController _iceController;

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box('settings');
    _loadSettings();
  }

  void _loadSettings() {
    _mapStyle = _settingsBox.get('map_style', defaultValue: 'Standard');
    _pushEnabled = _settingsBox.get('push_enabled', defaultValue: true);
    _soundEnabled = _settingsBox.get('sound_enabled', defaultValue: true);
    _vibrationEnabled = _settingsBox.get('vibration_enabled', defaultValue: true);
    _alertSound = _settingsBox.get('alert_sound', defaultValue: 'Standard Tone');
    _pingInterval = _settingsBox.get('ping_interval', defaultValue: 3.0);
    _autoOfflineIdle = _settingsBox.get('auto_offline_idle', defaultValue: 'Never');
    _autoRejectSeconds = _settingsBox.get('auto_reject_seconds', defaultValue: 30.0);
    _navApp = _settingsBox.get('nav_app', defaultValue: 'Google Maps');
    _language = _settingsBox.get('language', defaultValue: 'English');
    
    final savedIce = _settingsBox.get('ice_contact', defaultValue: '');
    _iceController = TextEditingController(text: savedIce);
  }

  void _saveSetting(String key, dynamic value) {
    _settingsBox.put(key, value);
  }



  @override
  void dispose() {
    _iceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(themeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? kDarkBg : kLightBg;
    final surfaceColor = isDark ? kDarkSurface : kLightSurface;
    final borderColor = isDark ? kDarkBorder : kLightBorder;
    final textColor = isDark ? kDarkText : kLightText;
    final subtextColor = isDark ? kDarkSubtext : kLightSubtext;
    final mutedColor = isDark ? kDarkMuted : kLightMuted;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('SETTINGS', style: TextStyle(color: textColor)),
        backgroundColor: bgColor,
        iconTheme: IconThemeData(color: textColor),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader(title: 'APPEARANCE'),

            // Theme Toggle
            Text('Theme Mode:', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSegmentButton('☀ Light', ThemeMode.light, currentTheme == ThemeMode.light, borderColor),
                _buildSegmentButton('◑ System', ThemeMode.system, currentTheme == ThemeMode.system, borderColor),
                _buildSegmentButton('● Dark', ThemeMode.dark, currentTheme == ThemeMode.dark, borderColor),
              ],
            ),
            const SizedBox(height: 16),

            // Map Style Dropdown
            Text('Map style:', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _mapStyle,
                  dropdownColor: surfaceColor,
                  style: AppTheme.monoSm.copyWith(color: textColor),
                  icon: Icon(Icons.arrow_drop_down, color: textColor),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'Standard', child: Text('Standard')),
                    DropdownMenuItem(value: 'Satellite', child: Text('Satellite')),
                    DropdownMenuItem(value: 'High Contrast', child: Text('High Contrast')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _mapStyle = val);
                      _saveSetting('map_style', val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),

            const SectionHeader(title: 'NOTIFICATIONS'),
            
            // Push toggle
            _buildSwitchTile('Push alerts', _pushEnabled, (val) {
              setState(() => _pushEnabled = val);
              _saveSetting('push_enabled', val);
            }, textColor),

            // Sound toggle
            _buildSwitchTile('Sound on incoming dispatch', _soundEnabled, (val) {
              setState(() => _soundEnabled = val);
              _saveSetting('sound_enabled', val);
            }, textColor),

            // Vibration toggle
            _buildSwitchTile('Vibration feedback', _vibrationEnabled, (val) {
              setState(() => _vibrationEnabled = val);
              _saveSetting('vibration_enabled', val);
            }, textColor),
            const SizedBox(height: 16),

            // Sound drop down
            Text('Alert sound selector:', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _alertSound,
                  dropdownColor: surfaceColor,
                  style: AppTheme.monoSm.copyWith(color: textColor),
                  icon: Icon(Icons.arrow_drop_down, color: textColor),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'Standard Tone', child: Text('Standard Tone')),
                    DropdownMenuItem(value: 'Siren Echo', child: Text('Siren Echo')),
                    DropdownMenuItem(value: 'Git Beep', child: Text('Git Beep')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _alertSound = val);
                      _saveSetting('alert_sound', val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),

            const SectionHeader(title: 'PATROL CONFIG'),

            // Location ping interval
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Location ping interval', style: TextStyle(color: textColor)),
                Text('${_pingInterval.toInt()}s', style: AppTheme.monoSm.copyWith(color: kAccentGreen, fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: _pingInterval,
              min: 3.0,
              max: 30.0,
              divisions: 9,
              activeColor: kAccentGreen,
              inactiveColor: borderColor,
              onChanged: (val) {
                setState(() => _pingInterval = val);
                _saveSetting('ping_interval', val);
              },
            ),

            // Auto-go-offline after idle dropdown
            Text('Auto-go-offline after idle:', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _autoOfflineIdle,
                  dropdownColor: surfaceColor,
                  style: AppTheme.monoSm.copyWith(color: textColor),
                  icon: Icon(Icons.arrow_drop_down, color: textColor),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: '30m', child: Text('30 minutes')),
                    DropdownMenuItem(value: '1h', child: Text('1 hour')),
                    DropdownMenuItem(value: '2h', child: Text('2 hours')),
                    DropdownMenuItem(value: 'Never', child: Text('Never')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _autoOfflineIdle = val);
                      _saveSetting('auto_offline_idle', val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Auto-reject dispatch after slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Auto-reject dispatch after', style: TextStyle(color: textColor)),
                Text('${_autoRejectSeconds.toInt()}s', style: AppTheme.monoSm.copyWith(color: kAccentRed, fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: _autoRejectSeconds,
              min: 15.0,
              max: 45.0,
              divisions: 2,
              activeColor: kAccentRed,
              inactiveColor: borderColor,
              onChanged: (val) {
                setState(() => _autoRejectSeconds = val);
                _saveSetting('auto_reject_seconds', val);
              },
            ),
            const SizedBox(height: 32),

            const SectionHeader(title: 'PREFERENCES'),

            // Navigation App
            Text('Navigation App:', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _navApp,
                  dropdownColor: surfaceColor,
                  style: AppTheme.monoSm.copyWith(color: textColor),
                  icon: Icon(Icons.arrow_drop_down, color: textColor),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'Google Maps', child: Text('Google Maps')),
                    DropdownMenuItem(value: 'Waze', child: Text('Waze')),
                    DropdownMenuItem(value: 'In-App Map', child: Text('In-App Map')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _navApp = val);
                      _saveSetting('nav_app', val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Language
            Text('Language:', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _language,
                  dropdownColor: surfaceColor,
                  style: AppTheme.monoSm.copyWith(color: textColor),
                  icon: Icon(Icons.arrow_drop_down, color: textColor),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'English', child: Text('English')),
                    DropdownMenuItem(value: 'Hindi', child: Text('Hindi')),
                    DropdownMenuItem(value: 'Tamil', child: Text('Tamil')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _language = val);
                      _saveSetting('language', val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),

            const SectionHeader(title: 'EMERGENCY'),

            // ICE Contact
            Text('In Case of Emergency (ICE) Contact:', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _iceController,
              keyboardType: TextInputType.phone,
              style: AppTheme.monoSm.copyWith(color: textColor),
              decoration: InputDecoration(
                filled: true,
                fillColor: surfaceColor,
                hintText: 'e.g. +91 98765 43210',
                hintStyle: AppTheme.monoSm.copyWith(color: mutedColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: kAccentGreen),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (val) {
                _saveSetting('ice_contact', val);
              },
            ),
            const SizedBox(height: 24),

            // Version info
            Center(
              child: Text(
                'RoadSOS Officer v1.4.2 · Build 88\nCOERS IIT Madras 2026',
                textAlign: TextAlign.center,
                style: AppTheme.monoSm.copyWith(color: mutedColor, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton(String label, ThemeMode mode, bool isSelected, Color borderColor) {
    return Expanded(
      child: InkWell(
        onTap: () {
          ref.read(themeProvider.notifier).setTheme(mode);
        },
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: isSelected ? kAccentGreen : Colors.transparent,
            border: Border.all(color: isSelected ? kAccentGreen : borderColor, width: 0.5),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTheme.monoSm.copyWith(
              color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? kDarkText : kLightText),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool val, ValueChanged<bool> onChanged, Color textColor) {
    return SwitchListTile(
      title: Text(title, style: TextStyle(color: textColor, fontSize: 14)),
      value: val,
      activeColor: kAccentGreen,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }
}
