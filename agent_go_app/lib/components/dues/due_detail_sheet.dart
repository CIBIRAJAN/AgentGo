import 'package:flutter/material.dart';
import '../../config/theme/app_colors.dart';
import '../../models/monthly_due_model.dart';
import '../../utils/formatters.dart';
import '../common/status_badge.dart';

/// Detail view when user taps a due card showing all info.
class DueDetailSheet extends StatelessWidget {
  final MonthlyDueModel due;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
  final VoidCallback? onAutoCall;
  final VoidCallback? onEmail;
  final VoidCallback? onMarkPaid;

  const DueDetailSheet({
    super.key,
    required this.due,
    this.onCall,
    this.onWhatsApp,
    this.onAutoCall,
    this.onEmail,
    this.onMarkPaid,
  });

  static void show(BuildContext context, MonthlyDueModel due,
      {VoidCallback? onCall,
      VoidCallback? onWhatsApp,
      VoidCallback? onAutoCall,
      VoidCallback? onEmail,
      VoidCallback? onMarkPaid}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DueDetailSheet(
        due: due,
        onCall: onCall,
        onWhatsApp: onWhatsApp,
        onAutoCall: onAutoCall,
        onEmail: onEmail,
        onMarkPaid: onMarkPaid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Name + Status
            Row(
              children: [
                Expanded(
                  child: Text(
                    due.displayName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                StatusBadge(status: due.status),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Policy: ${due.policyNumber}',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            if (due.clientMode != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _modeLabel(due.clientMode!),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.primary),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Premium details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primarySurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _DetailRow('Premium', Formatters.currency(due.premiumAmount)),
                  _DetailRow('GST', Formatters.currency(due.gstAmount)),
                  const Divider(height: 16),
                  _DetailRow('Total Premium',
                      Formatters.currency(due.totalPremium),
                      isBold: true),
                  const SizedBox(height: 8),
                  _DetailRow('Due Month', Formatters.dueMonth(due.dueMonth)),
                  _DetailRow('Status', due.status.toUpperCase(),
                      color: due.isPaid
                          ? AppColors.success
                          : AppColors.warning),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action buttons
            if (!due.isPaid)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: (MediaQuery.of(context).size.width - 48) / 2,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onCall?.call();
                      },
                      icon: const Icon(Icons.phone_rounded,
                          color: AppColors.success, size: 18),
                      label: const Text('Call'),
                    ),
                  ),
                  SizedBox(
                    width: (MediaQuery.of(context).size.width - 48) / 2,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onWhatsApp?.call();
                      },
                      icon: const Icon(Icons.chat_rounded,
                          color: Color(0xFF25D366), size: 18),
                      label: const Text('WhatsApp'),
                    ),
                  ),
                  if (due.clientEmail != null)
                    SizedBox(
                      width: (MediaQuery.of(context).size.width - 48) / 2,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onEmail?.call();
                        },
                        icon: const Icon(Icons.email_rounded,
                            color: AppColors.secondary, size: 18),
                        label: const Text('Email'),
                      ),
                    ),
                  SizedBox(
                    width: (MediaQuery.of(context).size.width - 48) / (due.clientEmail != null ? 2 : 2), // Keep it consistent
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onMarkPaid?.call();
                      },
                      icon: const Icon(Icons.check_circle_rounded,
                          size: 18),
                      label: const Text('Paid'),
                    ),
                  ),
                ],
              ),
              /*
              if (!due.isPaid) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onAutoCall?.call();
                        },
                        icon: const Icon(Icons.smart_toy_rounded,
                            color: Color(0xFF8B5CF6), size: 18),
                        label: const Text('Auto Call (AI)'),
                      ),
                    ),
                  ],
                ),
              ],
              */
          ],
        ),
      ),
    );
  }

  String _modeLabel(String mode) {
    return switch (mode.toLowerCase()) {
      'hly' => 'Half-Yearly (Hly)',
      'qly' => 'Quarterly (Qly)',
      'mly' => 'Monthly (Mly)',
      _ => mode,
    };
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? color;

  const _DetailRow(this.label, this.value,
      {this.isBold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    )),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                  color: color ?? AppColors.textPrimary,
                ),
          ),
        ],
      ),
    );
  }
}
