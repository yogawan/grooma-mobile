import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/auth_controller.dart';
import '../services/branch_service.dart';
import '../services/change_request_service.dart';
import '../services/dashboard_service.dart';
import '../services/inventory_service.dart';
import '../services/profile_service.dart';
import '../services/service_catalog_service.dart';
import '../services/staff_service.dart';
import '../services/subscription_service.dart';
import '../services/transaction_service.dart';
import '../widgets/home_nav_scaffold.dart';
import 'dashboard_screen.dart';
import 'inventory_list_screen.dart';
import 'kelola_hub_screen.dart';
import 'profile_screen.dart';
import 'transaction_list_screen.dart';

/// HOST home — bottom navbar per docs/MOBILE-BOTTOM-NAVBAR.md: Dashboard/
/// Transaksi/Inventaris/Kelola/Profil. Persetujuan lives inside the
/// Transaksi tab as a sub-page (doc "Persetujuan (Change Request) —
/// HOST"); this screen only tracks the PENDING count shown as a badge
/// on that tab's icon. HOST has no standalone Customer tab by design
/// (doc "Apa Itu Tab Kelola") — customer access for HOST belongs inside
/// the Transaksi flow instead.
class HostHomeScreen extends StatefulWidget {
  const HostHomeScreen({
    super.key,
    required this.authController,
    required this.dashboardService,
    required this.profileService,
    required this.transactionService,
    required this.changeRequestService,
    required this.inventoryService,
    required this.branchService,
    required this.staffService,
    required this.serviceCatalogService,
    required this.subscriptionService,
    required this.user,
  });

  final AuthController authController;
  final DashboardService dashboardService;
  final ProfileService profileService;
  final TransactionService transactionService;
  final ChangeRequestService changeRequestService;
  final InventoryService inventoryService;
  final BranchService branchService;
  final StaffService staffService;
  final ServiceCatalogService serviceCatalogService;
  final SubscriptionService subscriptionService;
  final User user;

  @override
  State<HostHomeScreen> createState() => _HostHomeScreenState();
}

class _HostHomeScreenState extends State<HostHomeScreen> {
  int? _pendingApprovalCount;

  @override
  void initState() {
    super.initState();
    _loadPendingApprovalCount();
  }

  Future<void> _loadPendingApprovalCount() async {
    try {
      final result = await widget.changeRequestService.listPending(limit: 1);
      if (!mounted) return;
      setState(() => _pendingApprovalCount = result.pagination.total);
    } catch (_) {
      // Best-effort only — the badge just stays hidden if this fails;
      // the Persetujuan sub-page itself still surfaces any real error.
    }
  }

  @override
  Widget build(BuildContext context) {
    return HomeNavScaffold(
      tabs: [
        NavTab(
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          label: 'Dashboard',
          page: Scaffold(
            appBar: AppBar(title: const Text('Dashboard')),
            body: DashboardScreen(
              dashboardService: widget.dashboardService,
              user: widget.user,
            ),
          ),
        ),
        NavTab(
          icon: Icons.point_of_sale_outlined,
          selectedIcon: Icons.point_of_sale,
          label: 'Transaksi',
          badgeCount: _pendingApprovalCount,
          page: TransactionListScreen(
            transactionService: widget.transactionService,
            changeRequestService: widget.changeRequestService,
            authController: widget.authController,
            user: widget.user,
            onChangeRequestsReviewed: _loadPendingApprovalCount,
          ),
        ),
        NavTab(
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2,
          label: 'Inventaris',
          page: InventoryListScreen(
            inventoryService: widget.inventoryService,
            user: widget.user,
          ),
        ),
        NavTab(
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
          label: 'Kelola',
          page: KelolaHubScreen(
            branchService: widget.branchService,
            staffService: widget.staffService,
            serviceCatalogService: widget.serviceCatalogService,
            subscriptionService: widget.subscriptionService,
          ),
        ),
        NavTab(
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          label: 'Profil',
          page: ProfileScreen(
            profileService: widget.profileService,
            authController: widget.authController,
          ),
        ),
      ],
    );
  }
}
