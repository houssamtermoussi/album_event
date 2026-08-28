import 'package:flutter/material.dart';

class AppColors {
  // Monochrome palette
  static const Color black = Colors.black;
  static const Color white = Colors.white;

  static const Color grey900 = Color(0xFF212121);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey50 = Color(0xFFFAFAFA);

  // Semantic (minimalist approach, mostly greys)
  static const Color primary = black;
  static const Color backgroundLight = white;
  static const Color surfaceLight = white;

  static const Color backgroundDark = black;
  static const Color surfaceDark = grey900;

  static const Color textPrimaryLight = black;
  static const Color textSecondaryLight = grey600;

  static const Color textPrimaryDark = white;
  static const Color textSecondaryDark = grey300;

  static const Color dividerLight = grey300;
  static const Color dividerDark = grey800;

  static const Color error = Color(0xFFD32F2F);
}
