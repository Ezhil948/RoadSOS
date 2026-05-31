import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class Helpline {
  final String name;
  final String number;
  final String description;

  const Helpline({
    required this.name,
    required this.number,
    required this.description,
  });
}

class HelplineCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final List<Helpline> lines;

  const HelplineCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.lines,
  });
}

const List<HelplineCategory> kHelplineCategories = [
  HelplineCategory(
    id: 'police',
    name: 'Police & Law',
    icon: Icons.local_police_rounded,
    color: AppTheme.accentBlue,
    lines: [
      Helpline(name: 'Police Control Room', number: '100', description: 'Immediate police response'),
      Helpline(name: 'National Emergency', number: '112', description: 'All emergencies'),
      Helpline(name: 'Women Helpline', number: '1091', description: 'Violence against women'),
      Helpline(name: 'Anti-Terrorism', number: '1090', description: 'Terror tips'),
    ],
  ),
  HelplineCategory(
    id: 'medical',
    name: 'Medical',
    icon: Icons.local_hospital_rounded,
    color: AppTheme.accentGreen,
    lines: [
      Helpline(name: 'Ambulance', number: '108', description: 'Free ambulance'),
      Helpline(name: 'NIMHANS Mental Health', number: '080-46110007', description: 'Psychiatric crisis'),
      Helpline(name: 'COVID Helpline', number: '1075', description: 'Health ministry helpline'),
    ],
  ),
  HelplineCategory(
    id: 'fire',
    name: 'Fire & Disaster',
    icon: Icons.local_fire_department_rounded,
    color: AppTheme.primaryRed,
    lines: [
      Helpline(name: 'Fire Brigade', number: '101', description: 'Fire emergencies'),
      Helpline(name: 'NDRF Disaster', number: '011-24363260', description: 'Natural disaster relief'),
    ],
  ),
  HelplineCategory(
    id: 'railway',
    name: 'Railway',
    icon: Icons.train_rounded,
    color: AppTheme.accentTeal,
    lines: [
      Helpline(name: 'Railway Emergency', number: '139', description: 'Train accidents, derailments'),
      Helpline(name: 'Railway Inquiry', number: '139', description: 'Train status'),
      Helpline(name: 'RPF (Railway Police)', number: '182', description: 'Railway crime/theft'),
    ],
  ),
  HelplineCategory(
    id: 'transport',
    name: 'Road Transport',
    icon: Icons.directions_bus_rounded,
    color: AppTheme.accentAmber,
    lines: [
      Helpline(name: 'Highway Patrol', number: '1033', description: 'National highway patrol'),
      Helpline(name: 'Road Accident Emergency', number: '1073', description: 'Roadside emergencies'),
      Helpline(name: 'NHAI Helpline', number: '1033', description: 'Highway issues'),
    ],
  ),
  HelplineCategory(
    id: 'women_child',
    name: 'Child & Women Safety',
    icon: Icons.child_care_rounded,
    color: AppTheme.accentPurple,
    lines: [
      Helpline(name: 'Child Helpline', number: '1098', description: 'Child abuse, runaway children'),
      Helpline(name: 'Women Helpline', number: '181', description: 'Domestic abuse'),
      Helpline(name: 'Sexual Harassment (SHe-Box)', number: '011-23386929', description: 'Workplace harassment'),
      Helpline(name: 'Anti-Trafficking', number: '1800-419-8588', description: 'Human trafficking'),
    ],
  ),
  HelplineCategory(
    id: 'mental_health',
    name: 'Mental Health',
    icon: Icons.psychology_rounded,
    color: AppTheme.accentPink,
    lines: [
      Helpline(name: 'iCall (TISS)', number: '9152987821', description: 'Free counselling'),
      Helpline(name: 'Vandrevala Foundation', number: '1860-2662-345', description: '24/7 mental health support'),
      Helpline(name: 'Snehi Helpline', number: '044-24640050', description: 'Suicide prevention'),
      Helpline(name: 'AASRA', number: '9820466627', description: 'Crisis intervention'),
    ],
  ),
  HelplineCategory(
    id: 'consumer_legal',
    name: 'Consumer & Legal',
    icon: Icons.gavel_rounded,
    color: AppTheme.accentAmber,
    lines: [
      Helpline(name: 'Consumer Helpline', number: '1800-11-4000', description: 'Consumer complaints'),
      Helpline(name: 'Cyber Crime', number: '1930', description: 'Online fraud, cybercrime'),
      Helpline(name: 'Anti-Corruption', number: '1800-11-0180', description: 'Corruption reporting'),
      Helpline(name: 'Legal Aid', number: '15100', description: 'Free legal services'),
    ],
  ),
  HelplineCategory(
    id: 'banking',
    name: 'Banking & Finance',
    icon: Icons.account_balance_rounded,
    color: AppTheme.accentGreen,
    lines: [
      Helpline(name: 'RBI Helpline', number: '14448', description: 'Banking complaints'),
      Helpline(name: 'Bank Fraud Helpline', number: '155260', description: 'Online banking fraud'),
    ],
  ),
];
