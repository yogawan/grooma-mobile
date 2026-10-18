import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Centered icon + title + message + retry button, for full-screen
/// loading-failed/locked states. Shared by DashboardScreen and
/// ProfileScreen rather than duplicated per screen.
class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.secondaryText),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}
