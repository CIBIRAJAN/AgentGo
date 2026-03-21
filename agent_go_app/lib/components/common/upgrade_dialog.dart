import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../config/theme/app_colors.dart';
import '../../screens/subscription/subscription_screen.dart';

class UpgradeDialog {
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
  }) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.workspace_premium_rounded, size: 48, color: AppColors.primary),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
            child: const Text('Upgrade Plan'),
          ),
        ],
      ),
    );
  }
}
