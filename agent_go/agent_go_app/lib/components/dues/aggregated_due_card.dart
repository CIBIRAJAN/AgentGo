import 'package:flutter/material.dart';
import '../../config/theme/app_colors.dart';
import '../../models/aggregated_due_model.dart';
import '../../utils/formatters.dart';

class AggregatedDueCard extends StatelessWidget {
  final AggregatedDueModel due;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback? onEmail;
  final VoidCallback onAutoCall;
  final VoidCallback onMarkPaid;

  const AggregatedDueCard({
    super.key,
    required this.due,
    required this.onCall,
    required this.onWhatsApp,
    this.onEmail,
    required this.onAutoCall,
    required this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: due.status == 'lapsed' ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  child: Icon(
                    due.status == 'lapsed' ? Icons.warning_rounded : Icons.history_rounded,
                    color: due.status == 'lapsed' ? Colors.red : Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        due.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.pin_rounded, size: 12, color: AppColors.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            due.policyNumber,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.currency(due.totalPremium),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: due.status == 'lapsed' ? Colors.red : Colors.orange[800],
                      ),
                    ),
                    Text(
                      '${due.unpaidMonthsCount} months unpaid',
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Unpaid Months',
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        due.unpaidMonthsList,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: onMarkPaid,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary.withOpacity(0.1),
                    foregroundColor: AppColors.secondary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Mark Paid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ActionIcon(icon: Icons.call_rounded, color: AppColors.secondary, onTap: onCall),
                _ActionIcon(icon: Icons.chat_bubble_rounded, color: const Color(0xFF25D366), onTap: onWhatsApp),
                if (onEmail != null) _ActionIcon(icon: Icons.email_rounded, color: AppColors.secondary, onTap: onEmail!),
                _AutoCallButton(onTap: onAutoCall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionIcon({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _AutoCallButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AutoCallButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.smart_toy_rounded, size: 18),
      label: const Text('Auto-Call', style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
