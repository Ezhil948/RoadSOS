import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/components.dart';
import '../../widgets/git_badge.dart';
import '../../widgets/stat_row.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  String _selectedScope = 'month'; // month, station, district
  String _selectedMetric = 'dispatches'; // dispatches, response_time, false_alarm, rating

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bgColor = isDark ? kDarkBg : kLightBg;
    final surfaceColor = isDark ? kDarkSurface : kLightSurface;
    final borderColor = isDark ? kDarkBorder : kLightBorder;
    final textColor = isDark ? kDarkText : kLightText;
    final subtextColor = isDark ? kDarkSubtext : kLightSubtext;
    final mutedColor = isDark ? kDarkMuted : kLightMuted;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'OFFICER LEADERBOARD — MAY 2026'),

              // Scope Tab Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildScopeChip('This Month', 'month'),
                    const SizedBox(width: 8),
                    _buildScopeChip('Station (Central)', 'station'),
                    const SizedBox(width: 8),
                    _buildScopeChip('District', 'district'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Metric Selection Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildMetricChip('Dispatches', 'dispatches'),
                    const SizedBox(width: 8),
                    _buildMetricChip('Avg Response', 'response_time'),
                    const SizedBox(width: 8),
                    _buildMetricChip('False Alarms', 'false_alarm'),
                    const SizedBox(width: 8),
                    _buildMetricChip('Rating', 'rating'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Podium Widget
              _buildPodium(surfaceColor, borderColor, textColor, subtextColor),
              const SizedBox(height: 24),

              // Ranking Lists
              Expanded(
                child: ListView(
                  children: [
                    _buildRankRow(
                      rank: 4,
                      name: 'SGT. RAJAN KUMAR',
                      value: _getMetricValue(4, _selectedMetric),
                      isCurrentUser: true,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textColor: textColor,
                    ),
                    const SizedBox(height: 8),
                    _buildRankRow(
                      rank: 5,
                      name: 'PC MEENA IYER',
                      value: _getMetricValue(5, _selectedMetric),
                      isCurrentUser: false,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textColor: textColor,
                    ),
                    const SizedBox(height: 8),
                    _buildRankRow(
                      rank: 6,
                      name: 'INSP. ARUN SINGH',
                      value: _getMetricValue(6, _selectedMetric),
                      isCurrentUser: false,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textColor: textColor,
                    ),
                    const SizedBox(height: 8),
                    _buildRankRow(
                      rank: 7,
                      name: 'PC VIJAY SHARMA',
                      value: _getMetricValue(7, _selectedMetric),
                      isCurrentUser: false,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textColor: textColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScopeChip(String label, String value) {
    final isSelected = _selectedScope == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? kDarkBorder : kLightBorder;

    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : (isDark ? kDarkText : kLightText))),
      selected: isSelected,
      selectedColor: kAccentGreenDim,
      backgroundColor: isDark ? kDarkSurface : kLightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: isSelected ? kAccentGreenDim : borderColor, width: 0.5),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedScope = value;
          });
        }
      },
    );
  }

  Widget _buildMetricChip(String label, String value) {
    final isSelected = _selectedMetric == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? kDarkBorder : kLightBorder;

    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : (isDark ? kDarkSubtext : kLightSubtext))),
      selected: isSelected,
      selectedColor: kAccentBlue,
      backgroundColor: isDark ? kDarkSurface : kLightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: isSelected ? kAccentBlue : borderColor, width: 0.5),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedMetric = value;
          });
        }
      },
    );
  }

  Widget _buildPodium(Color surfaceColor, Color borderColor, Color textColor, Color subtextColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 2nd Place (Left)
        _buildPodiumBar(
          rank: 2,
          badge: '#4819',
          name: 'PC K. PATEL',
          value: _getMetricValue(2, _selectedMetric),
          height: 100,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textColor: textColor,
          subtextColor: subtextColor,
        ),
        // 1st Place (Center - Tallest)
        _buildPodiumBar(
          rank: 1,
          badge: '#3982',
          name: 'SGT. A. KHAN',
          value: _getMetricValue(1, _selectedMetric),
          height: 140,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textColor: textColor,
          subtextColor: subtextColor,
          isFirst: true,
        ),
        // 3rd Place (Right)
        _buildPodiumBar(
          rank: 3,
          badge: '#5023',
          name: 'PC S. REDDY',
          value: _getMetricValue(3, _selectedMetric),
          height: 80,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textColor: textColor,
          subtextColor: subtextColor,
        ),
      ],
    );
  }

  Widget _buildPodiumBar({
    required int rank,
    required String badge,
    required String name,
    required String value,
    required double height,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
    bool isFirst = false,
  }) {
    return Column(
      children: [
        Text(value, style: AppTheme.monoSm.copyWith(fontWeight: FontWeight.bold, color: isFirst ? kAccentGreen : kAccentBlue)),
        Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        Text(badge, style: AppTheme.monoSm.copyWith(color: subtextColor, fontSize: 10)),
        const SizedBox(height: 8),
        Container(
          width: 70,
          height: height,
          decoration: BoxDecoration(
            color: isFirst ? kAccentGreen.withOpacity(0.15) : surfaceColor,
            border: Border.all(color: isFirst ? kAccentGreen : borderColor, width: isFirst ? 2 : 1),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '#$rank',
            style: AppTheme.monoLg.copyWith(
              fontSize: 24,
              color: isFirst ? kAccentGreen : textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankRow({
    required int rank,
    required String name,
    required String value,
    required bool isCurrentUser,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: isCurrentUser ? kAccentGreen : borderColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                '#${rank.toString().padLeft(2, '0')}',
                style: AppTheme.monoMd.copyWith(color: isCurrentUser ? kAccentGreen : textColor, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                  if (isCurrentUser)
                    Text('(YOU)', style: AppTheme.monoSm.copyWith(color: kAccentGreen, fontSize: 10)),
                ],
              ),
            ],
          ),
          Text(
            value,
            style: AppTheme.monoMd.copyWith(color: isCurrentUser ? kAccentGreen : kAccentBlue, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _getMetricValue(int rank, String metric) {
    if (metric == 'dispatches') {
      final values = [18, 15, 13, 12, 11, 10, 8];
      return '${values[rank - 1]} disp';
    } else if (metric == 'response_time') {
      final values = ['4m 12s', '4m 45s', '5m 10s', '5m 42s', '6m 01s', '6m 20s', '7m 15s'];
      return values[rank - 1];
    } else if (metric == 'false_alarm') {
      final values = ['0%', '0%', '0%', '0%', '8%', '10%', '0%'];
      return values[rank - 1];
    } else {
      final values = ['4.98 ★', '4.95 ★', '4.94 ★', '4.92 ★', '4.89 ★', '4.85 ★', '4.80 ★'];
      return values[rank - 1];
    }
  }
}
