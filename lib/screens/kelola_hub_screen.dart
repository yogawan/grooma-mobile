import 'package:flutter/material.dart';

import '../services/branch_service.dart';
import '../services/service_catalog_service.dart';
import '../services/staff_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_colors.dart';
import 'branch_list_screen.dart';
import 'service_list_screen.dart';
import 'staff_list_screen.dart';
import 'subscription_screen.dart';

/// 4-tile hub for the HOST-only "Kelola" area. Cabang/Karyawan/Layanan
/// are all `ENFORCED` — when the subscription is lapsed only
/// Subscription & Billing still works (Kelola doc §0). Rather than let
/// HOST tap into 3 separate screens and hit 402 one at a time, this
/// checks status once up front and disables those 3 tiles with an
/// explanatory banner if lapsed, pointing straight at Subscription.
///
/// The check runs in the background rather than blocking the screen —
/// the common case is an active subscription, so tiles start enabled
/// and only get disabled if the check comes back locked. A sub-screen
/// opened in that brief window still handles 402 gracefully on its
/// own either way.
class KelolaHubScreen extends StatefulWidget {
  const KelolaHubScreen({
    super.key,
    required this.branchService,
    required this.staffService,
    required this.serviceCatalogService,
    required this.subscriptionService,
  });

  final BranchService branchService;
  final StaffService staffService;
  final ServiceCatalogService serviceCatalogService;
  final SubscriptionService subscriptionService;

  @override
  State<KelolaHubScreen> createState() => _KelolaHubScreenState();
}

class _KelolaHubScreenState extends State<KelolaHubScreen> {
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _checkSubscription();
  }

  Future<void> _checkSubscription() async {
    try {
      final subscription = await widget.subscriptionService.getStatus();
      if (mounted && (subscription?.status.isLocked ?? false)) {
        setState(() => _locked = true);
      }
    } catch (_) {
      // Best-effort only — each sub-screen still handles 402 on its
      // own if this check fails or simply hasn't resolved yet.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_locked)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Subscription tidak aktif — Cabang, Karyawan, dan Layanan '
                'terkunci sampai dibayar. Buka Subscription & Billing di bawah.',
                style: TextStyle(color: AppColors.warning),
              ),
            ),
          _tile(
            context,
            icon: Icons.store_outlined,
            label: 'Cabang',
            enabled: !_locked,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    BranchListScreen(branchService: widget.branchService),
              ),
            ),
          ),
          _tile(
            context,
            icon: Icons.badge_outlined,
            label: 'Karyawan',
            enabled: !_locked,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StaffListScreen(
                  staffService: widget.staffService,
                  branchService: widget.branchService,
                ),
              ),
            ),
          ),
          _tile(
            context,
            icon: Icons.design_services_outlined,
            label: 'Layanan',
            enabled: !_locked,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ServiceListScreen(
                  serviceCatalogService: widget.serviceCatalogService,
                ),
              ),
            ),
          ),
          _tile(
            context,
            icon: Icons.receipt_long_outlined,
            label: 'Subscription & Billing',
            enabled: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SubscriptionScreen(
                  subscriptionService: widget.subscriptionService,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        enabled: enabled,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
