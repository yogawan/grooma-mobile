import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/auth_controller.dart';
import '../services/change_request_service.dart';
import '../services/customer_service.dart';
import '../services/dashboard_service.dart';
import '../services/inventory_service.dart';
import '../services/profile_service.dart';
import '../services/transaction_service.dart';
import '../widgets/home_drawer.dart';
import 'customer_list_screen.dart';
import 'dashboard_screen.dart';
import 'inventory_list_screen.dart';
import 'profile_screen.dart';
import 'transaction_list_screen.dart';

/// AGENT home. The full AGENT bottom navbar from
/// docs/MOBILE-BOTTOM-NAVBAR.md (Transaksi/Customer/Inventaris/
/// Dashboard/Profil) still can't be built — the navbar itself is a
/// separate layout change — so [HomeDrawer] stands in for it, same as
/// HostHomeScreen.
class AgentHomeScreen extends StatelessWidget {
  const AgentHomeScreen({
    super.key,
    required this.authController,
    required this.dashboardService,
    required this.profileService,
    required this.transactionService,
    required this.changeRequestService,
    required this.inventoryService,
    required this.customerService,
    required this.user,
  });

  final AuthController authController;
  final DashboardService dashboardService;
  final ProfileService profileService;
  final TransactionService transactionService;
  final ChangeRequestService changeRequestService;
  final InventoryService inventoryService;
  final CustomerService customerService;
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
