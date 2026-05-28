import 'package:flutter/material.dart';

class DialogUtils {
  static void showSimulatedCallDialog(BuildContext context, String label, String number) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Simulated Call: $label'),
        content: Text('Simulating call to $number ($label)...\n\n(No actual phone call was placed)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
