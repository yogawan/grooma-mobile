import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/auth_controller.dart';
import '../services/branch_service.dart';
import '../services/change_request_service.dart';
import '../services/customer_service.dart';
import '../services/dashboard_service.dart';
import '../services/inventory_service.dart';
import '../services/profile_service.dart';
import '../services/service_catalog_service.dart';
import '../services/staff_service.dart';
import '../services/subscription_service.dart';
import '../services/transaction_service.dart';
import '../widgets/home_drawer.dart';
import 'change_request_queue_screen.dart';
import 'customer_list_screen.dart';
import 'dashboard_screen.dart';
import 'inventory_list_screen.dart';
import 'kelola_hub_screen.dart';
import 'profile_screen.dart';
import 'transaction_list_screen.dart';

/// HOST home. The full HOST bottom navbar from
/// docs/MOBILE-BOTTOM-NAVBAR.md (Dashboard/Transaksi/Inventaris/
/// Kelola/Profil) still can't be built — the navbar itself is a
/// separate layout change — so [HomeDrawer] stands in for it. Every
/// doc it depends on now exists, including this one (Kelola), so that
/// rework is now fully unblocked whenever it's wanted.
class HostHomeScreen extends StatelessWidget {
  const HostHomeScreen({
    super.key,
    required this.authController,
    required this.dashboardService,
    required this.profileService,
    required this.transactionService,
    required this.changeRequestService,
    required this.inventoryService,
    required this.customerService,
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
  final CustomerService customerService;
  final BranchService branchService;
  final StaffService staffService;
  final ServiceCatalogService serviceCatalogService;
  final SubscriptionService subscriptionService;
  final User user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: authController.logout,
          ),
        ],
      ),
      drawer: HomeDrawer(
        user: user,
        items: [
          DrawerItem(
            icon: Icons.point_of_sale_outlined,
            label: 'Transaksi',
            builder: (_) => TransactionListScreen(
              transactionService: transactionService,
              changeRequestService: changeRequestService,
              authController: authController,
              user: user,
            ),
          ),
          DrawerItem(
            icon: Icons.pending_actions_outlined,
            label: 'Persetujuan Koreksi',
            builder: (_) => ChangeRequestQueueScreen(
              transactionService: transactionService,
              changeRequestService: changeRequestService,
              authController: authController,
              user: user,
            ),
          ),
          DrawerItem(
            icon: Icons.inventory_2_outlined,
            label: 'Inventaris',
            builder: (_) => InventoryListScreen(
              inventoryService: inventoryService,
              user: user,
            ),
          ),
          DrawerItem(
            icon: Icons.people_outline,
            label: 'Customer',
            builder: (_) => CustomerListScreen(
              customerService: customerService,
              user: user,
            ),
          ),
          DrawerItem(
            icon: Icons.settings_outlined,
            label: 'Kelola',
            builder: (_) => KelolaHubScreen(
              branchService: branchService,
              staffService: staffService,
              serviceCatalogService: serviceCatalogService,
              subscriptionService: subscriptionService,
            ),
          ),
          DrawerItem(
            icon: Icons.person_outline,
            label: 'Profil',
            builder: (_) => ProfileScreen(
              profileService: profileService,
              authController: authController,
            ),
          ),
        ],
      ),
      body: DashboardScreen(dashboardService: dashboardService, user: user),
    );
  }
}
