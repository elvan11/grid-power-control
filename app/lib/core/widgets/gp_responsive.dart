import 'package:flutter/material.dart';

enum GpWindowSize { compact, medium, expanded }

class GpResponsiveBreakpoints {
  const GpResponsiveBreakpoints._();

  static const double compactMaxWidth = 599;
  static const double mediumMaxWidth = 1023;

  static GpWindowSize layoutForWidth(double width) {
    if (width <= compactMaxWidth) {
      return GpWindowSize.compact;
    }
    if (width <= mediumMaxWidth) {
      return GpWindowSize.medium;
    }
    return GpWindowSize.expanded;
  }

  static EdgeInsets pagePaddingFor(GpWindowSize size) {
    return switch (size) {
      GpWindowSize.compact => const EdgeInsets.fromLTRB(16, 20, 16, 16),
      GpWindowSize.medium => const EdgeInsets.fromLTRB(24, 24, 24, 20),
      GpWindowSize.expanded => const EdgeInsets.fromLTRB(32, 28, 32, 24),
    };
  }

  static double defaultMaxContentWidthFor(GpWindowSize size) {
    return switch (size) {
      GpWindowSize.compact => double.infinity,
      GpWindowSize.medium => 960,
      GpWindowSize.expanded => 1240,
    };
  }
}

extension GpResponsiveContext on BuildContext {
  GpWindowSize get gpWindowSize {
    return GpResponsiveBreakpoints.layoutForWidth(
      MediaQuery.sizeOf(this).width,
    );
  }

  bool get isCompact => gpWindowSize == GpWindowSize.compact;
  bool get isMedium => gpWindowSize == GpWindowSize.medium;
  bool get isExpanded => gpWindowSize == GpWindowSize.expanded;
}
