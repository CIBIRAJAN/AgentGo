import 'package:flutter/material.dart';
import '../../config/theme/app_colors.dart';
import '../../models/monthly_due_model.dart';
import '../../utils/formatters.dart';
import '../common/status_badge.dart';

/// A card displaying a single monthly due record with action buttons.
class DueCard extends StatelessWidget {
  final MonthlyDueModel due;
  final VoidCallback? onTap;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
  final VoidCallback? onAutoCall;
  final VoidCallback? onEmail;
  final VoidCallback? onMarkPaid;

  const DueCard({
    super.key,
    required this.due,
    this.onTap,
    this.onCall,
    this.onWhatsApp,
    this.onAutoCall,
    this.onEmail,
    this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: name + mode + status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              due.displayName,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (due.clientMode != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _modeColor(due.clientMode!)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                due.clientMode!,
                                style: TextStyle(
                                  color: _modeColor(due.clientMode!),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Policy: ${due.policyNumber}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: due.status),
              ],
            ),
            const SizedBox(height: 12),

            // Premium details row
            Row(
              children: [
                _InfoChip(
                  label: 'Premium',
                  value: Formatters.currency(due.premiumAmount),
                ),
                const SizedBox(width: 12),
                _InfoChip(
                  label: 'GST',
                  value: Formatters.currency(due.gstAmount),
                ),
                const SizedBox(width: 12),
                _InfoChip(
                  label: 'Total',
                  value: Formatters.currency(due.totalPremium),
                  isBold: true,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Due month
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  Formatters.dueMonth(due.dueMonth),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),

            // Action buttons (only for pending/overdue)
            if (!due.isPaid) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                children: [
                  _ActionButton(
                    icon: Icons.phone_rounded,
                    label: 'Call',
                    color: AppColors.success,
                    onTap: onCall,
                  ),
                  _ActionButton(
                    icon: Icons.chat_rounded,
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    onTap: onWhatsApp,
                  ),
                  if (onEmail != null && due.clientEmail != null)
                    _ActionButton(
                      icon: Icons.email_rounded,
                      label: 'Email',
                      color: AppColors.secondary,
                      onTap: onEmail,
                    ),
                  /*
                  _ActionButton(
                    icon: Icons.smart_toy_rounded,
                    label: 'Auto Call',
                    color: const Color(0xFF8B5CF6),
                    onTap: onAutoCall,
                  ),
                  */
                  _ActionButton(
                    icon: Icons.check_circle_rounded,
                    label: 'Mark Paid',
                    color: AppColors.primary,
                    onTap: onMarkPaid,
                    filled: true,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Color _modeColor(String mode) {
    return switch (mode.toLowerCase()) {
      'hly' => const Color(0xFF0EA5E9),
      'qly' => const Color(0xFFF59E0B),
      'mly' => const Color(0xFF8B5CF6),
      _ => AppColors.textTertiary,
    };
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _InfoChip({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool filled;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: filled ? Colors.white : color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: filled ? Colors.white : color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
