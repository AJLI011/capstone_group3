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

  // MUST be added to define the method called by your UI code
  /// Scales a base value (like padding, width, or height) based on the factor.
  double scaleValue(BuildContext context, double baseValue) {
    return baseValue * getScaleFactor(context);
  }

  // MUST be added to define the method called by your UI code
  /// Scales a font size, often good practice to use a dedicated function.
  double scaleFontSize(BuildContext context, double baseFontSize) {
    return baseFontSize * getScaleFactor(context); 
  }
}