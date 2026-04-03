import 'package:flutter/material.dart';

const nothingRed = Color(0xFFFF0000);

// Chat message colors
const chatMessageRedDarkBg = Color(0xFF7F1D1D);
const chatMessageRedDarkBorder = Color(0xFFB91C1C);
const chatMessageRedLight = Color(0xFFEF4444);

class AppTheme {
  static final light = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: const ColorScheme.light(
      primary: nothingRed,
      surface: Colors.white,
    ),
    fontFamily: 'Courier',
  );

  static final dark = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.black,
    colorScheme: const ColorScheme.dark(
      primary: nothingRed,
      surface: Colors.black,
    ),
    fontFamily: 'Courier',
  );
}
