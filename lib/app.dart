import 'package:flutter/material.dart';

import 'models/user.dart';
import 'screens/agent_home_screen.dart';
import 'screens/host_home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auth_controller.dart';
import 'services/branch_service.dart';
import 'services/change_request_service.dart';
import 'services/customer_service.dart';
import 'services/dashboard_service.dart';
import 'services/inventory_service.dart';
import 'services/profile_service.dart';
import 'services/service_catalog_service.dart';
import 'services/staff_service.dart';
import 'services/subscription_service.dart';
import 'services/transaction_service.dart';
import 'theme/app_theme.dart';

class App extends StatelessWidget {
  const App({
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
  });

  final AuthController authController;
  final DashboardService dashboardService;
  final ProfileService profileService;
  final TransactionService transactionService;
  final ChangeRequestService changeRequestService;
  final InventoryService inventoryService;
  final CustomerService customerService;
  // The following 4 are HOST-only (Kelola tab, Kelola doc §0) and are
  // only ever threaded into HostHomeScreen, never AgentHomeScreen.
  final BranchService branchService;
  final StaffService staffService;
  final ServiceCatalogService serviceCatalogService;
  final SubscriptionService subscriptionService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grooma',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: ListenableBuilder(
        listenable: authController,
        builder: (context, _) {
          switch (authController.status) {
            case AuthStatus.unknown:
              return const SplashScreen();
            case AuthStatus.unauthenticated:
              return LoginScreen(authController: authController);
            case AuthStatus.authenticated:
              final user = authController.user!;
              return user.role == UserRole.host
                  ? HostHomeScreen(
                      authController: authController,
                      dashboardService: dashboardService,
                      profileService: profileService,
                      transactionService: transactionService,
                      changeRequestService: changeRequestService,
                      inventoryService: inventoryService,
                      branchService: branchService,
                      staffService: staffService,
                      serviceCatalogService: serviceCatalogService,
                      subscriptionService: subscriptionService,
                      user: user,
                    )
                  : AgentHomeScreen(
                      authController: authController,
                      dashboardService: dashboardService,
                      profileService: profileService,
                      transactionService: transactionService,
                      changeRequestService: changeRequestService,
                      inventoryService: inventoryService,
                      customerService: customerService,
                      user: user,
                    );
          }
        },
      ),
    );
  }
}
