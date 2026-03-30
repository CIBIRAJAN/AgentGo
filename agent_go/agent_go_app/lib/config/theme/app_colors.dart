import 'package:flutter/material.dart';

/// Refined Neobank-style color palette for AgentGo.
class AppColors {
  AppColors._();

  // ── Brand Colors ──
  static const Color primary = Color(0xFFC9F158); // High-vis Lime Green
  static const Color primaryLight = Color(0xFFD6F57A);
  static const Color primaryDark = Color(0xFFAECF4D);
  static const Color primarySurface = Color(0xFFF4FAE1);

  // ── Secondary / Dark Green (Premium Branding) ──
  static const Color secondary = Color(0xFF064E3B); // Very Dark Green
  static const Color secondaryLight = Color(0xFF065F46);
  static const Color secondaryDark = Color(0xFF022C22);

  // ── Status Colors ──
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color successDark = Color(0xFF059669);
  
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFFD97706);
  
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color errorDark = Color(0xFFDC2626);

  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFEFF6FF);

  // ── Neutrals ──
  static const Color background = Color(0xFFF2F3F5); // Clean light grey
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFE8EAED);
  static const Color border = Color(0xFFE0E2E6);
  static const Color borderLight = Color(0xFFF0F1F5);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFF064E3B); // Dark green text on lime
  static const Color textOnDark = Color(0xFFFFFFFF);

  // ── Shadows ──
  static const Color shadow = Color(0x0A000000);
  static const Color shadowDark = Color(0x1A000000);

  // ── Gradients ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Hero gradient is now DARK GREEN for a premium feel
  static const LinearGradient heroGradient = LinearGradient(
    colors: [secondary, Color(0xFF053E31)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [secondary, secondaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}




