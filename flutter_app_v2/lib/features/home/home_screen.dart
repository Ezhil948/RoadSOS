import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../emergency/emergency_tab.dart';
import '../helplines/helplines_tab.dart';
import '../nearby/nearby_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppTheme.borderDark, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.sos_rounded, color: _selectedIndex == 0 ? AppTheme.primaryRed : AppTheme.textMuted),
              label: 'Emergency',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.phone_in_talk_rounded, color: _selectedIndex == 1 ? AppTheme.accentBlue : AppTheme.textMuted),
              label: 'Helplines',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.location_on_rounded, color: _selectedIndex == 2 ? AppTheme.accentGreen : AppTheme.textMuted),
              label: 'Nearby',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 1:
        return const HelplinesTab();
      case 2:
        return const NearbyTab();
      case 0:
      default:
        return const EmergencyTab();
    }
  }
}
