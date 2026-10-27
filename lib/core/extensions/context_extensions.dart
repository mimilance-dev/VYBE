import 'package:flutter/widgets.dart';

extension BuildContextLayout on BuildContext {
  double get viewportWidth => MediaQuery.sizeOf(this).width;

  bool get isCompactLayout => viewportWidth < 960;
}