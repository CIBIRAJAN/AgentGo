import 'package:intl/intl.dart';

/// Utility formatting functions used across the app.
class Formatters {
  Formatters._();

  /// Format currency in Indian Rupees.
  static String currency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  /// Format currency with decimals.
  static String currencyWithDecimals(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  /// Format a date as "dd MMM yyyy" (e.g., 08 Mar 2026).
  static String date(DateTime? date) {
    if (date == null) return '—';
    return DateFormat('dd MMM yyyy').format(date);
  }

  /// Short date "dd/MM/yy".
  static String shortDate(DateTime? date) {
    if (date == null) return '—';
    return DateFormat('dd/MM/yy').format(date);
  }

  /// Combine date and time "dd MMM yyyy, hh:mm a"
  static String dateTime(DateTime? date) {
    if (date == null) return '—';
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  /// Relative time (e.g., "2 hours ago").
  static String timeAgo(DateTime? date) {
    if (date == null) return '—';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(date);
  }

  /// Format phone number for display.
  static String phone(String? cc, String? number) {
    if (number == null || number.isEmpty) return '—';
    final code = cc ?? '+91';
    return '$code $number';
  }

  /// Format due month for display (e.g., "2026-03" → "March 2026").
  static String dueMonth(String? month) {
    if (month == null || month.isEmpty) return '—';
    try {
      final parts = month.split('-');
      if (parts.length == 2) {
        final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
        return DateFormat('MMMM yyyy').format(date);
      }
      return month;
    } catch (_) {
      return month;
    }
  }

  /// Current month in "yyyy-MM" format.
  static String currentMonth() {
    return DateFormat('yyyy-MM').format(DateTime.now());
  }

  /// Format currency in a compact way (e.g. 1.2K).
  static String compactCurrency(double amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(1)}Cr';
    }
    if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(1)}L';
    }
    if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(0)}K';
    }
    return '₹${amount.toInt()}';
  }

  /// Percentage string.
  static String percent(double? value) {
    if (value == null) return '0%';
    return '${value.toStringAsFixed(1)}%';
  }
}
