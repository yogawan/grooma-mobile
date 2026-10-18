import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/auth_controller.dart';
import '../services/change_request_service.dart';
import '../services/customer_service.dart';
import '../services/dashboard_service.dart';
import '../services/inventory_service.dart';
import '../services/profile_service.dart';
import '../services/transaction_service.dart';
import '../widgets/home_nav_scaffold.dart';
import 'customer_list_screen.dart';
import 'dashboard_screen.dart';
import 'inventory_list_screen.dart';
import 'profile_screen.dart';
import 'transaction_list_screen.dart';

/// AGENT home — bottom navbar per docs/MOBILE-BOTTOM-NAVBAR.md:
/// Transaksi/Customer/Inventaris/Dashboard/Profil. Order intentionally
/// differs from HOST — Transaksi comes first since it's AGENT's daily
/// POS work, unlike HOST who opens the overview first.
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
    return HomeNavScaffold(
      tabs: [
        NavTab(
          icon: Icons.point_of_sale_outlined,
          selectedIcon: Icons.point_of_sale,
          label: 'Transaksi',
          page: TransactionListScreen(
            transactionService: transactionService,
            changeRequestService: changeRequestService,
            authController: authController,
            user: user,
          ),
        ),
        NavTab(
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          label: 'Customer',
          page: CustomerListScreen(
            customerService: customerService,
            user: user,
          ),
        ),
        NavTab(
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2,
          label: 'Inventaris',
          page: InventoryListScreen(
            inventoryService: inventoryService,
            user: user,
          ),
        ),
        NavTab(
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          label: 'Dashboard',
          page: Scaffold(
            appBar: AppBar(title: const Text('Dashboard')),
            body: DashboardScreen(
              dashboardService: dashboardService,
              user: user,
            ),
          ),
        ),
        NavTab(
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          label: 'Profil',
          page: ProfileScreen(
            profileService: profileService,
            authController: authController,
          ),
        ),
      ],
    );
  }
}
