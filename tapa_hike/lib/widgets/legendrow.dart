import 'package:flutter/material.dart';

class LegendRow extends StatelessWidget {
  final Color color;
  final String text;
  const LegendRow({super.key, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.circle, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}
