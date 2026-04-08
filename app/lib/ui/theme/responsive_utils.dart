import 'package:flutter/widgets.dart';

class Responsive {
  static late double screenWidth;
  static late double screenHeight;

  /// Call this inside the first build method (e.g., in a main screen or root wrapper)
  static void init(BuildContext context) {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
  }

  /// Scale pixel values relative to a baseline width of 390 (iPhone 14)
  static double sp(double size) {
    if (screenWidth == 0) return size; // Fallback
    return (size / 390.0) * screenWidth;
  }

  /// Scale vertical heights relative to a baseline height of 844 (iPhone 14)
  static double h(double height) {
    if (screenHeight == 0) return height; // Fallback
    return (height / 844.0) * screenHeight;
  }

  /// Scale down on small screens, but never scale up beyond [size].
  /// Keeps Pixel-class devices pixel-perfect while shrinking on narrow ones.
  static double clampSp(double size) => sp(size).clamp(0, size);

  /// Determines if the device is considered exceptionally 'small' (like iPhone SE)
  static bool get isSmallDevice => screenHeight != 0 && screenHeight < 700;
}
