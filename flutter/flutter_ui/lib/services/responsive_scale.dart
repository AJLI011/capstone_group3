import 'package:flutter/material.dart';

mixin ResponsiveScale {
  // Reference screen width (e.g., a common medium phone width for scaling)
  static const double referenceWidth = 400.0; 

  // Calculates a scaling factor based on the current device width
  double getScaleFactor(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    // Clamped to prevent UI elements from becoming too large or too small
    return (screenW / referenceWidth).clamp(0.8, 1.5);
  }
}