import 'package:flutter/material.dart';
import '../../core/constants/helpline_data.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/helpline_card.dart';

class HelplineCategoryPage extends StatelessWidget {
  final HelplineCategory category;

  const HelplineCategoryPage({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            Icon(category.icon, color: category.color, size: 24),
            const SizedBox(width: 12),
            Text(category.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: category.lines.length,
        itemBuilder: (context, index) {
          return HelplineCard(
            helpline: category.lines[index],
            categoryColor: category.color,
          );
        },
      ),
    );
  }
}
