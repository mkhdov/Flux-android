import 'package:flutter/material.dart';

class AppColors {
  // Primary brand colors (from web: coral #FF5A5F)
  static const Color primary = Color(0xFFFF5A5F);
  static const Color primaryLight = Color(0xFFFF7A7D);
  static const Color accent = Color(0xFFFF5A5F);

  // Background colors (dark theme from web)
  static const Color darkBg = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF202020);
  static const Color darkCard = Color(0xFF1C1C1E);
  static const Color darkCardAlt = Color(0xFF2A2A2C);
  static const Color darkBorder = Color(0xFF2D2D2D);
  static const Color darkBorderLight =
      Color(0x1AFFFFFF); // rgba(255,255,255,0.1)

  // Background colors (light theme)
  static const Color lightBg = Color(0xFFF6F2EC);
  static const Color lightSurface = Color(0xFFFFF7EE);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardAlt = Color(0xFFF2ECE4);
  static const Color lightBorder = Color(0xFFEADFD2);
  static const Color lightBorderLight = Color(0x1F3D3129);

  // Text colors
  static const Color textPrimary = Color(0xFFE8E8E8);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFF4B5563);

  // Text colors (light theme)
  static const Color lightTextPrimary = Color(0xFF231F20);
  static const Color lightTextSecondary = Color(0xFF5F5A55);
  static const Color lightTextMuted = Color(0xFF847A70);
  static const Color lightTextDisabled = Color(0xFFAA9E93);

  // Status colors
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFF34D399);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFF87171);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Calendar / Event colors
  static const List<Color> eventPresets = [
    Color(0xFF6366F1),
    Color(0xFFEC4899),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
  ];

  // Priority colors
  static const Color priorityHigh = Color(0xFFFF5A5F);
  static const Color priorityMedium = Color(0xFFF59E0B);
  static const Color priorityLow = Color(0xFF6B7280);

  // Status colors for tasks
  static const Color statusTodo = Color(0xFF9CA3AF);
  static const Color statusInProgress = Color(0xFF3B82F6);
  static const Color statusDone = Color(0xFF22C55E);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) =>
      isDark(context) ? darkBg : lightBg;
  static Color card(BuildContext context) =>
      isDark(context) ? darkCard : lightCard;
  static Color cardAlt(BuildContext context) =>
      isDark(context) ? darkCardAlt : lightCardAlt;
  static Color border(BuildContext context) =>
      isDark(context) ? darkBorder : lightBorder;
  static Color adaptiveTextPrimary(BuildContext context) =>
      isDark(context) ? textPrimary : lightTextPrimary;
  static Color adaptiveTextSecondary(BuildContext context) =>
      isDark(context) ? textSecondary : lightTextSecondary;
  static Color adaptiveTextMuted(BuildContext context) =>
      isDark(context) ? textMuted : lightTextMuted;
  static Color adaptiveTextDisabled(BuildContext context) =>
      isDark(context) ? textDisabled : lightTextDisabled;
}
