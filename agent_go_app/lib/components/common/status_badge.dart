import 'package:flutter/material.dart';
import '../../config/theme/app_colors.dart';

/// Reusable status badge component for due/reminder statuses.
class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.status,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.borderColor, width: 0.5),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          color: config.textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  _StatusConfig _getConfig() {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'completed':
      case 'received':
      case 'delivered':
        return _StatusConfig(
          label: status.toUpperCase(),
          bgColor: AppColors.successLight,
          textColor: AppColors.successDark,
          borderColor: AppColors.success.withValues(alpha: 0.3),
        );
      case 'pending':
      case 'uploaded':
        return _StatusConfig(
          label: status.toUpperCase(),
          bgColor: AppColors.warningLight,
          textColor: AppColors.warningDark,
          borderColor: AppColors.warning.withValues(alpha: 0.3),
        );
      case 'overdue':
      case 'failed':
      case 'lapsed':
      case 'not_received':
        return _StatusConfig(
          label: status.toUpperCase(),
          bgColor: AppColors.errorLight,
          textColor: AppColors.errorDark,
          borderColor: AppColors.error.withValues(alpha: 0.3),
        );
      case 'processing':
      case 'sent':
        return _StatusConfig(
          label: status.toUpperCase(),
          bgColor: AppColors.infoLight,
          textColor: AppColors.info,
          borderColor: AppColors.info.withValues(alpha: 0.3),
        );
      default:
        return _StatusConfig(
          label: status.toUpperCase(),
          bgColor: AppColors.surfaceVariant,
          textColor: AppColors.textSecondary,
          borderColor: AppColors.border,
        );
    }
  }
}

class _StatusConfig {
  final String label;
  final Color bgColor;
  final Color textColor;
  final Color borderColor;

  const _StatusConfig({
    required this.label,
    required this.bgColor,
    required this.textColor,
    required this.borderColor,
  });
}
