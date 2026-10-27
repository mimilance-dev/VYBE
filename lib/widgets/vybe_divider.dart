import 'package:flutter/material.dart';

class VYBEDivider extends StatelessWidget {
  const VYBEDivider({this.padding = const EdgeInsets.symmetric(vertical: 16), super.key});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
    );
  }
}