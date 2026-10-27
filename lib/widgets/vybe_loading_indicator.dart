import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class VYBELoadingIndicator extends StatelessWidget {
  const VYBELoadingIndicator({this.label = 'Loading', super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      liveRegion: true,
      child: const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.secondary,
        ),
      ),
    );
  }
}