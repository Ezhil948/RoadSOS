import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/helpline_data.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_card.dart';
import 'helpline_category_page.dart';
import '../nearby/nearby_tab.dart';

class HelplinesTab extends StatefulWidget {
  const HelplinesTab({super.key});

  @override
  State<HelplinesTab> createState() => _HelplinesTabState();
}

class _HelplinesTabState extends State<HelplinesTab> {

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Helplines', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 4),
                const Text('Government of India official helplines', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: kHelplineCategories.length,
              itemBuilder: (context, index) {
                final category = kHelplineCategories[index];
                return GlassCard(
                  color: category.color,
                  icon: category.icon,
                  title: category.name,
                  subtitle: '${category.lines.length} numbers',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HelplineCategoryPage(category: category),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
