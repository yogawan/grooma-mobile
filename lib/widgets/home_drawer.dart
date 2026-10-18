import 'package:flutter/material.dart';

import '../models/user.dart';
import '../theme/app_colors.dart';

class DrawerItem {
  const DrawerItem({
    required this.icon,
    required this.label,
    required this.builder,
  });

  final IconData icon;
  final String label;
  final WidgetBuilder builder;
}

/// Shared Drawer shell for both Host/AgentHomeScreen — stands in for
/// the real bottom navbar from docs/MOBILE-BOTTOM-NAVBAR.md until the
/// modules it also depends on (Kelola's Cabang/Karyawan/Layanan/
/// Customer/Subscription) have docs to build from.
class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key, required this.user, required this.items});

  final User user;
  final List<DrawerItem> items;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  user.name,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: AppColors.onPrimary),
                ),
                Text(
                  user.role == UserRole.host ? 'Host' : 'Agent',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onPrimary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          for (final item in items)
            ListTile(
              leading: Icon(item.icon),
              title: Text(item.label),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: item.builder));
              },
            ),
        ],
      ),
    );
  }
}
