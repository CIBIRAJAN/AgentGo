import 'package:flutter/material.dart';

/// Curated, harmonious color palette for AgentGo.
/// Inspired by LIC's branding with a modern, premium feel.
class AppColors {
  AppColors._();

  // ── Primary (Deep Indigo-Blue) ──
  static const Color primary = Color(0xFF3B3FBF);
  static const Color primaryLight = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF2D2FA3);
  static const Color primarySurface = Color(0xFFEEF0FF);

  // ── Secondary (Warm Gold – LIC inspired) ──
  static const Color secondary = Color(0xFFD4A843);
  static const Color secondaryLight = Color(0xFFF5DFA3);
  static const Color secondaryDark = Color(0xFFB88B2A);

  // ── Success / Paid ──
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color successDark = Color(0xFF059669);

  // ── Warning / Pending ──
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFFD97706);

  // ── Error / Overdue ──
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color errorDark = Color(0xFFDC2626);

  // ── Info ──
  static const Color info = Color(0xFF06B6D4);
  static const Color infoLight = Color(0xFFCFFAFE);

  // ── Neutrals ──
  static const Color background = Color(0xFFF8F9FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F3F9);
  static const Color border = Color(0xFFE2E6EF);
  static const Color borderLight = Color(0xFFF0F1F5);
  static const Color textPrimary = Color(0xFF1A1D2E);
  static const Color textSecondary = Color(0xFF6B7290);
  static const Color textTertiary = Color(0xFF9CA3C0);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnDark = Color(0xFFF8F9FC);

  // ── Shadows ──
  static const Color shadow = Color(0x0F1A1D2E);
  static const Color shadowDark = Color(0x1F1A1D2E);

  // ── Gradient Combinations ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [secondary, secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF3B3FBF), Color(0xFF6366F1), Color(0xFF818CF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
