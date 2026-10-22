import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/user.dart';
import '../services/auth_controller.dart';
import '../services/change_request_service.dart';
import '../services/customer_service.dart';
import '../services/dashboard_service.dart';
import '../services/inventory_service.dart';
import '../services/profile_service.dart';
import '../services/service_catalog_service.dart';
import '../services/transaction_service.dart';
import '../widgets/home_nav_scaffold.dart';
import 'customer_list_screen.dart';
import 'dashboard_screen.dart';
import 'inventory_list_screen.dart';
import 'profile_screen.dart';
import 'transaction_list_screen.dart';

/// AGENT home — bottom navbar per docs/MOBILE-BOTTOM-NAVBAR.md:
/// Dashboard/Customer/Transaksi/Inventaris/Profil.
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
    required this.serviceCatalogService,
    required this.user,
  });

  final AuthController authController;
  final DashboardService dashboardService;
  final ProfileService profileService;
  final TransactionService transactionService;
  final ChangeRequestService changeRequestService;
  final InventoryService inventoryService;
  final CustomerService customerService;
  // Read-only for AGENT in practice — only ever used here to populate
  // the "pilih layanan" picker in Transaksi Baru (MOBILE-BOTTOM-NAVBAR
  // doc "Soal Layanan/Service"). Write endpoints are HOST-only and
  // enforced server-side regardless of what this app does client-side.
  final ServiceCatalogService serviceCatalogService;
  final User user;

  @override
  Widget build(BuildContext context) {
    return HomeNavScaffold(
      tabs: [
        NavTab(
          icon: LucideIcons.layoutDashboard,
          selectedIcon: LucideIcons.layoutDashboard,
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
          icon: LucideIcons.users,
          selectedIcon: LucideIcons.users,
          label: 'Customer',
          page: CustomerListScreen(
            customerService: customerService,
            user: user,
          ),
        ),
        NavTab(
          icon: LucideIcons.store,
          selectedIcon: LucideIcons.store,
          label: 'Transaksi',
          page: TransactionListScreen(
            transactionService: transactionService,
            changeRequestService: changeRequestService,
            authController: authController,
            user: user,
            customerService: customerService,
            serviceCatalogService: serviceCatalogService,
          ),
        ),
        NavTab(
          icon: LucideIcons.package,
          selectedIcon: LucideIcons.package,
          label: 'Inventaris',
          page: InventoryListScreen(
            inventoryService: inventoryService,
            user: user,
          ),
        ),
        NavTab(
          icon: LucideIcons.user,
          selectedIcon: LucideIcons.user,
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
