import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'services/api_client.dart';
import 'services/auth_controller.dart';
import 'services/auth_service.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = await ApiClient.create();
  final authController = AuthController(AuthService(apiClient.dio));
  final dashboardService = DashboardService(apiClient.dio);
  final profileService = ProfileService(apiClient.dio);
  final transactionService = TransactionService(apiClient.dio);
  final changeRequestService = ChangeRequestService(apiClient.dio);
  final inventoryService = InventoryService(apiClient.dio);
  final customerService = CustomerService(apiClient.dio);
  final branchService = BranchService(apiClient.dio);
  final staffService = StaffService(apiClient.dio);
  final serviceCatalogService = ServiceCatalogService(apiClient.dio);
  final subscriptionService = SubscriptionService(apiClient.dio);
  apiClient.onUnauthenticated = authController.handleUnauthenticated;
  unawaited(authController.checkSession());

  runApp(
    App(
      authController: authController,
      dashboardService: dashboardService,
      profileService: profileService,
      transactionService: transactionService,
      changeRequestService: changeRequestService,
      inventoryService: inventoryService,
      customerService: customerService,
      branchService: branchService,
      staffService: staffService,
      serviceCatalogService: serviceCatalogService,
      subscriptionService: subscriptionService,
    ),
  );
}
