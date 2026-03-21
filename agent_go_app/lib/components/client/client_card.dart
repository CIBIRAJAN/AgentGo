import 'package:flutter/material.dart';
import '../../config/theme/app_colors.dart';
import '../../models/client_model.dart';

/// A card displaying client info — no overflow, shows mode badge.
class ClientCard extends StatelessWidget {
  final ClientModel client;
  final VoidCallback? onTap;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;

  const ClientCard({
    super.key,
    required this.client,
    this.onTap,
    this.onCall,
    this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: (client.profileImageUrl == null || client.profileImageUrl!.isEmpty)
                    ? AppColors.primaryGradient
                    : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: (client.profileImageUrl != null && client.profileImageUrl!.isNotEmpty)
                    ? Image.network(
                        client.profileImageUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            _initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          _initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),

            // Info — use Expanded + Flexible to avoid overflow
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name row with mode badge
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          client.fullName ?? 'Unknown',
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (client.mode != null) ...[
                        const SizedBox(width: 6),
                        _ModeBadge(mode: client.mode!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Agent Badge
                  if (client.ownerName != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Agent: ${client.ownerName}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                  // Policy + phone on separate line to avoid overflow
                  Row(
                    children: [
                      if (client.policyNumber != null) ...[
                        Icon(Icons.policy_rounded,
                            size: 12, color: AppColors.textTertiary),
                        const SizedBox(width: 3),
                        Text(
                          client.policyNumber!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                  if (client.mobileNumber != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.phone_rounded,
                            size: 12, color: AppColors.textTertiary),
                        const SizedBox(width: 3),
                        Text(
                          client.mobileNumber!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Arrow indicator
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary, size: 22),
          ],
        ),
      ),
    );
  }

  String get _initials {
    final name = client.fullName ?? '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

/// Small badge showing payment mode (Hly, Qly, Mly).
class _ModeBadge extends StatelessWidget {
  final String mode;
  const _ModeBadge({required this.mode});

  @override
  Widget build(BuildContext context) {
    final color = switch (mode.toLowerCase()) {
      'hly' => const Color(0xFF0EA5E9),
      'qly' => const Color(0xFFF59E0B),
      'mly' => const Color(0xFF8B5CF6),
      _ => AppColors.textTertiary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        mode,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
