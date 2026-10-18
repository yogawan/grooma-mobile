import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grooma/app.dart';
import 'package:grooma/models/customer.dart';
import 'package:grooma/models/managed_branch.dart';
import 'package:grooma/models/pagination.dart';
import 'package:grooma/models/profile.dart';
import 'package:grooma/models/user.dart';
import 'package:grooma/screens/customer_detail_screen.dart';
import 'package:grooma/screens/dashboard_screen.dart';
import 'package:grooma/screens/inventory_list_screen.dart';
import 'package:grooma/screens/profile_screen.dart';
import 'package:grooma/screens/transaction_detail_screen.dart';
import 'package:grooma/screens/transaction_list_screen.dart';
import 'package:grooma/services/auth_controller.dart';
import 'package:grooma/services/auth_service.dart';
import 'package:grooma/services/branch_service.dart';
import 'package:grooma/services/change_request_service.dart';
import 'package:grooma/services/customer_service.dart';
import 'package:grooma/services/dashboard_service.dart';
import 'package:grooma/services/inventory_service.dart';
import 'package:grooma/services/profile_service.dart';
import 'package:grooma/services/service_catalog_service.dart';
import 'package:grooma/services/staff_service.dart';
import 'package:grooma/services/subscription_service.dart';
import 'package:grooma/services/transaction_service.dart';

/// Returns a canned 200 response per dashboard endpoint, shaped exactly
/// like the examples in docs/DASHBOARD-MOBILE-API-INTEGRATION.md, so
/// DashboardScreen can be exercised end-to-end without a real backend.
class _FakeDashboardAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final Map<String, dynamic> body;
    final path = options.path;

    if (path.endsWith('/dashboard/summary')) {
      body = {
        'success': true,
        'data': {
          'summary': {
            'totalRevenue': 4250000,
            'transactionCount': 38,
            'avgOrderValue': 111842,
            'uniqueCustomers': 29,
          },
        },
      };
    } else if (path.endsWith('/dashboard/revenue')) {
      body = {
        'success': true,
        'data': {
          'revenue': {
            'byPeriod': [
              {
                '_id': {'year': 2026, 'month': 10},
                'revenue': 4250000,
                'transactionCount': 38,
                'ownerRevenue': 2975000,
                'agentRevenue': 1275000,
              },
            ],
            'paymentBreakdown': [
              {'_id': 'CASH', 'count': 20, 'revenue': 2100000},
              {'_id': 'QRIS', 'count': 18, 'revenue': 2150000},
            ],
          },
        },
      };
    } else if (path.endsWith('/dashboard/services')) {
      body = {
        'success': true,
        'data': {
          'services': [
            {
              '_id': '66ab12cd34ef56ab78cd90ef',
              'serviceName': 'Haircut + Styling',
              'count': 15,
              'revenue': 1500000,
              'avgOrderValue': 100000,
            },
          ],
          'meta': {'limit': 10, 'total': 1, 'truncated': false},
        },
      };
    } else if (path.endsWith('/dashboard/agents')) {
      body = {
        'success': true,
        'data': {
          'agents': [
            {
              '_id': '66ab12cd34ef56ab78cd90aa',
              'agentName': '66ab12cd34ef56ab78cd90aa',
              'transactionCount': 22,
              'totalRevenue': 2450000,
              'agentRevenue': 735000,
            },
          ],
          'meta': {'limit': 50, 'total': 1, 'truncated': false},
        },
      };
    } else if (path.endsWith('/dashboard/transactions')) {
      body = {
        'success': true,
        'data': {
          'stats': {
            'byStatus': [
              {'_id': 'COMPLETED', 'count': 35},
            ],
            'byPaymentStatus': [
              {'_id': 'PAID', 'count': 36},
            ],
            'byPaymentMethod': [
              {'_id': 'CASH', 'count': 20},
            ],
          },
        },
      };
    } else if (path.endsWith('/dashboard/inventory')) {
      body = {
        'success': true,
        'data': {
          'inventory': [
            {
              '_id': '66cc00112233445566778899',
              'branch': {
                '_id': '66ffaa0011223344556677aa',
                'name': 'Cabang Kemang',
              },
              'name': 'Pomade Matte 100g',
              'quantity': 2,
              'minimumStock': 5,
            },
          ],
          'meta': {'limit': 20, 'total': 1, 'truncated': false},
        },
      };
    } else {
      body = {
        'success': false,
        'error': {'code': 'NOT_FOUND', 'message': 'Unknown path: $path'},
      };
    }

    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(body)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// Serves GET /api/v1/profile from a fixed user map, and "persists" PATCH
/// edits onto that same map so a GET-then-PATCH-then-save test can verify
/// the round trip, matching the shape in
/// docs/PROFILE-MOBILE-API-INTEGRATION.md §1-2.
class _FakeProfileAdapter implements HttpClientAdapter {
  _FakeProfileAdapter(this._user);

  Map<String, dynamic> _user;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'PATCH') {
      final patch = options.data as Map<String, dynamic>? ?? {};
      _user = {..._user, ...patch};
    }

    final body = {
      'success': true,
      'data': {'user': _user},
    };
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(body)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// Serves a single canned transaction for both GET /transactions (list)
/// and GET /transactions/:id (detail), shaped like the populated
/// list/detail examples in docs/TRANSACTION-MOBILE-API-INTEGRATION.md
/// §2-3 — exercises the raw-id-vs-populated EntityRef parsing on real
/// `{_id, name}` objects (branch/agent/customer/requestedBy).
class _FakeTransactionAdapter implements HttpClientAdapter {
  _FakeTransactionAdapter(this.transactionJson);

  final Map<String, dynamic> transactionJson;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final Map<String, dynamic> body;
    if (options.path.endsWith('/transactions') && options.method == 'GET') {
      body = {
        'success': true,
        'data': {
          'transactions': [transactionJson],
          'pagination': {'page': 1, 'limit': 20, 'total': 1, 'totalPages': 1},
        },
      };
    } else {
      body = {
        'success': true,
        'data': {'transaction': transactionJson},
      };
    }

    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(body)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> _sampleTransactionJson({
  required Map<String, dynamic> changeRequest,
}) {
  return {
    '_id': '671234abcd5678ef90123456',
    'transactionCode': 'GRM-20261018-412837',
    'branch': {'_id': '66ffaa0011223344556677aa', 'name': 'Cabang Kemang'},
    'agent': {'_id': '66ab12cd34ef56ab78cd90aa', 'name': 'Budi Santoso'},
    'customer': {
      '_id': '66aa11bb22cc33dd44ee55ff',
      'name': 'Andi Wijaya',
      'phone': '08123456789',
    },
    'service': '66bb22cc33dd44ee55ff6600',
    'serviceSnapshot': {
      'name': 'Haircut + Styling',
      'price': 100000,
      'ownerPercentage': 70,
      'employeePercentage': 30,
    },
    'paymentMethod': 'QRIS',
    'paymentStatus': 'PENDING',
    'transactionStatus': 'PENDING',
    'serviceHourType': 'REGULAR',
    'subtotal': 100000,
    'discountAmount': 0,
    'total': 100000,
    'ownerRevenue': 70000,
    'employeeRevenue': 30000,
    'pointsEarned': 100,
    'paidAt': null,
    'completedAt': null,
    'changeRequest': changeRequest,
    'receipt': {'printed': false, 'printCount': 0},
    'createdAt': '2026-10-18T08:00:00.000Z',
  };
}

/// Serves a fixed two-item list for GET /api/v1/inventory, shaped like
/// docs/INVENTARIS-MOBILE-API-INTEGRATION.md §1 — one active+low-stock
/// item and one soft-deleted (isActive: false) item, to exercise both
/// badges in the same list.
class _FakeInventoryAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Map<String, dynamic> item({
      required String id,
      required String name,
      required int quantity,
      required bool isActive,
      required bool isLowStock,
    }) => {
      '_id': id,
      'itemCode': 'INV-$id',
      'branch': {'_id': '66ffaa0011223344556677aa', 'name': 'Cabang Kemang'},
      'name': name,
      'category': 'HAIR_PRODUCT',
      'unit': 'PCS',
      'quantity': quantity,
      'unitCost': 35000,
      'minimumStock': 5,
      'supplier': 'PT Sumber Rambut',
      'isActive': isActive,
      'totalValue': quantity * 35000,
      'isLowStock': isLowStock,
      'createdAt': '2026-09-01T03:00:00.000Z',
      'updatedAt': '2026-10-14T06:12:00.000Z',
    };

    final body = {
      'success': true,
      'data': {
        'items': [
          item(
            id: '1',
            name: 'Pomade Matte 100g',
            quantity: 2,
            isActive: true,
            isLowStock: true,
          ),
          item(
            id: '2',
            name: 'Shampoo Anti Ketombe',
            quantity: 20,
            isActive: false,
            isLowStock: false,
          ),
        ],
        'pagination': {'page': 1, 'limit': 20, 'total': 2, 'totalPages': 1},
      },
    };

    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(body)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// Captures the request body of every call so a test can assert on it
/// directly, instead of just trusting the response round-trips. Used
/// to verify InventoryService's discriminated-union body shapes.
class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter(this.onRequest);

  final void Function(Map<String, dynamic> body) onRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onRequest(options.data as Map<String, dynamic>);

    final body = {
      'success': true,
      'data': {
        'item': {
          '_id': '66cc00112233445566778899',
          'itemCode': 'INV-0012',
          'branch': {
            '_id': '66ffaa0011223344556677aa',
            'name': 'Cabang Kemang',
          },
          'name': 'Pomade Matte 100g',
          'category': 'HAIR_PRODUCT',
          'unit': 'PCS',
          'quantity': 27,
          'unitCost': 35000,
          'minimumStock': 5,
          'supplier': 'PT Sumber Rambut',
          'isActive': true,
          'totalValue': 945000,
          'isLowStock': false,
          'createdAt': '2026-09-01T03:00:00.000Z',
          'updatedAt': '2026-10-18T09:30:00.000Z',
        },
        'movement': {
          '_id': '66dd11223344556677889911',
          'branch': '66ffaa0011223344556677aa',
          'movementType': options.data['movementType'],
          'quantity': 20,
          'previousQuantity': 7,
          'newQuantity': 27,
          'reason': options.data['reason'],
          'performedBy': '66ab12cd34ef56ab78cd90aa',
          'createdAt': '2026-10-18T09:30:00.000Z',
        },
      },
    };

    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(body)),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// Serves a HOST-shaped customer (all 5 privileged fields present) for
/// GET /api/v1/customers/:id, matching
/// docs/CUSTOMER-MOBILE-API-INTEGRATION.md §2. Used to test
/// CustomerDetailScreen's own role-gating of the privileged section —
/// separately from whether `Customer.fromJson` can tolerate those keys
/// being absent, which is covered by a plain (non-widget) test below.
class _FakeCustomerAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = {
      'success': true,
      'data': {
        'customer': {
          'id': '66aa11bb22cc33dd44ee55ff',
          'customerCode': null,
          'name': 'Andi Wijaya',
          'phone': '6281234567890',
          'customerType': 'REGULAR',
          'loyaltyPoints': 450,
          'lastVisitAt': '2026-10-10T09:00:00.000Z',
          'isActive': true,
          'email': 'andi@example.com',
          'gender': 'MALE',
          'birthDate': '1995-05-20T00:00:00.000Z',
          'address': 'Jl. Kemang Raya No. 10',
          'notes': 'Suka potongan fade',
          'createdAt': '2026-01-10T08:00:00.000Z',
          'updatedAt': '2026-10-10T09:00:00.000Z',
        },
      },
    };

    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(body)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// Captures the request body and echoes back a canned response wrapped
/// under [responseKey] — generic across resources, used to verify the
/// Kelola doc's explicitly-called-out status-toggle shape mismatch
/// (Branch/Staff use `{status: "ACTIVE"|"INACTIVE"}`, Service uses
/// `{isActive: bool}`).
class _StatusCapturingAdapter implements HttpClientAdapter {
  _StatusCapturingAdapter(this.onRequest, this.responseKey, this.responseBody);

  final void Function(Map<String, dynamic> body) onRequest;
  final String responseKey;
  final Map<String, dynamic>? responseBody;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // GET calls (e.g. subscription status) have no body at all.
    if (options.data != null) {
      onRequest(options.data as Map<String, dynamic>);
    }

    final body = {
      'success': true,
      'data': {responseKey: responseBody},
    };
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(body)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// Serves GET /branches across 2 pages (3 branches total, `limit=100`)
/// so [BranchService.listAll]'s page-walking loop can be exercised
/// end-to-end — this is the exact "picker silently shows only 20" bug
/// AUTH doc §2.1.4 calls out, and the loop (not just response parsing)
/// is what actually guards against it.
class _PagedBranchAdapter implements HttpClientAdapter {
  int requestCount = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;

    Map<String, dynamic> branch(String id, String code, String name) => {
      '_id': id,
      'branchCode': code,
      'name': name,
      'timezone': 'Asia/Jakarta',
      'status': 'ACTIVE',
      'createdAt': '2026-01-05T04:00:00.000Z',
      'updatedAt': '2026-09-20T07:30:00.000Z',
    };

    final page = options.queryParameters['page'] as int;
    final branches = page == 1
        ? [
            branch('66ffaa0011223344556677aa', 'KMG', 'Cabang Kemang'),
            branch('66ffaa0011223344556677ab', 'SCM', 'Cabang Sudirman'),
          ]
        : [branch('66ffaa0011223344556677ac', 'BSD', 'Cabang BSD')];

    final body = {
      'success': true,
      'data': {
        'branches': branches,
        'pagination': {'page': page, 'limit': 100, 'total': 3, 'totalPages': 2},
      },
    };

    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(body)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  testWidgets('shows a loading indicator while the session check is pending', (
    WidgetTester tester,
  ) async {
    final authController = AuthController(AuthService(Dio()));

    await tester.pumpWidget(
      App(
        authController: authController,
        dashboardService: DashboardService(Dio()),
        profileService: ProfileService(Dio()),
        transactionService: TransactionService(Dio()),
        changeRequestService: ChangeRequestService(Dio()),
        inventoryService: InventoryService(Dio()),
        customerService: CustomerService(Dio()),
        branchService: BranchService(Dio()),
        staffService: StaffService(Dio()),
        serviceCatalogService: ServiceCatalogService(Dio()),
        subscriptionService: SubscriptionService(Dio()),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the login form once unauthenticated', (
    WidgetTester tester,
  ) async {
    final authController = AuthController(AuthService(Dio()))
      ..status = AuthStatus.unauthenticated;

    await tester.pumpWidget(
      App(
        authController: authController,
        dashboardService: DashboardService(Dio()),
        profileService: ProfileService(Dio()),
        transactionService: TransactionService(Dio()),
        changeRequestService: ChangeRequestService(Dio()),
        inventoryService: InventoryService(Dio()),
        customerService: CustomerService(Dio()),
        branchService: BranchService(Dio()),
        staffService: StaffService(Dio()),
        serviceCatalogService: ServiceCatalogService(Dio()),
        subscriptionService: SubscriptionService(Dio()),
      ),
    );

    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
  });

  testWidgets('renders every dashboard section once data loads', (
    WidgetTester tester,
  ) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://grooma.test'))
      ..httpClientAdapter = _FakeDashboardAdapter();
    const user = User(
      id: '671234abcd5678ef90123456',
      username: 'budi_agent',
      name: 'Budi Santoso',
      role: UserRole.agent,
      branch: Branch(id: '66ffaa0011223344556677aa', name: 'Cabang Kemang'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardScreen(
            dashboardService: DashboardService(dio),
            user: user,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ringkasan'), findsOneWidget);
    expect(find.text('Revenue'), findsOneWidget);
    expect(find.text('Top Layanan'), findsOneWidget);
    expect(find.text('Performa Agent'), findsOneWidget);
    expect(find.text('Transaksi'), findsOneWidget);
    // Title includes `meta.total` (dashboard doc §3.6 "‼️") — the fake
    // adapter's inventory response reports 1 low-stock item.
    expect(find.text('Stok Menipis (1)'), findsOneWidget);
    expect(find.textContaining('Pomade Matte 100g'), findsOneWidget);
    // AGENT always sees a single, self-only row (dashboard doc §3.4).
    expect(find.text('Anda'), findsOneWidget);
  });

  testWidgets('loads profile, edits the name, and saves', (
    WidgetTester tester,
  ) async {
    final adapter = _FakeProfileAdapter({
      'id': '671234abcd5678ef90123456',
      'username': 'budi_agent',
      'name': 'Budi Santoso',
      'role': 'AGENT',
      'branch': {'id': '66ffaa0011223344556677aa', 'name': 'Cabang Kemang'},
      'phone': '08123456789',
      'status': 'ACTIVE',
      'createdAt': '2026-09-01T10:30:00.000Z',
      'updatedAt': '2026-10-15T14:20:00.000Z',
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://grooma.test'))
      ..httpClientAdapter = adapter;
    final authController = AuthController(AuthService(Dio()))
      ..status = AuthStatus.authenticated
      ..user = const User(
        id: '671234abcd5678ef90123456',
        username: 'budi_agent',
        name: 'Budi Santoso',
        role: UserRole.agent,
        branch: Branch(id: '66ffaa0011223344556677aa', name: 'Cabang Kemang'),
      );

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          profileService: ProfileService(dio),
          authController: authController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Read-only fields from the GET response.
    expect(find.text('budi_agent'), findsOneWidget);
    expect(find.text('Agent'), findsOneWidget);
    expect(find.text('Cabang Kemang'), findsOneWidget);
    expect(find.text('Aktif'), findsOneWidget);
    // Editable fields pre-filled.
    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('08123456789'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Budi Santoso'),
      'Budi Santoso Wijaya',
    );
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Profil berhasil diperbarui'), findsOneWidget);
    // AuthController's cached user is kept in sync post-edit.
    expect(authController.user?.name, 'Budi Santoso Wijaya');
  });

  testWidgets('HOST transaction list shows the agent name in the subtitle', (
    WidgetTester tester,
  ) async {
    final transactionJson = _sampleTransactionJson(
      changeRequest: {'status': 'NONE'},
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://grooma.test'))
      ..httpClientAdapter = _FakeTransactionAdapter(transactionJson);
    const host = User(
      id: '66hosthosthosthosthost01',
      username: 'owner',
      name: 'Owner',
      role: UserRole.host,
      branch: null,
    );
    final authController = AuthController(AuthService(Dio()))
      ..status = AuthStatus.authenticated
      ..user = host;

    await tester.pumpWidget(
      MaterialApp(
        home: TransactionListScreen(
          transactionService: TransactionService(dio),
          changeRequestService: ChangeRequestService(dio),
          authController: authController,
          user: host,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GRM-20261018-412837'), findsOneWidget);
    // HOST sees the agent name; AGENT would not (see detail test below).
    expect(find.textContaining('Budi Santoso'), findsOneWidget);
    expect(find.text('Rp 100.000'), findsOneWidget);
  });

  testWidgets(
    'AGENT detail screen shows Selesaikan/Batalkan/Bayar QRIS/Ajukan Koreksi',
    (WidgetTester tester) async {
      final transactionJson = _sampleTransactionJson(
        changeRequest: {'status': 'NONE'},
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://grooma.test'))
        ..httpClientAdapter = _FakeTransactionAdapter(transactionJson);
      const agent = User(
        id: '66ab12cd34ef56ab78cd90aa',
        username: 'budi_agent',
        name: 'Budi Santoso',
        role: UserRole.agent,
        branch: Branch(id: '66ffaa0011223344556677aa', name: 'Cabang Kemang'),
      );
      final authController = AuthController(AuthService(Dio()))
        ..status = AuthStatus.authenticated
        ..user = agent;

      await tester.pumpWidget(
        MaterialApp(
          home: TransactionDetailScreen(
            transactionService: TransactionService(dio),
            changeRequestService: ChangeRequestService(dio),
            authController: authController,
            user: agent,
            transactionId: '671234abcd5678ef90123456',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Selesaikan'), findsOneWidget);
      expect(find.text('Batalkan'), findsOneWidget);
      expect(find.text('Bayar QRIS'), findsOneWidget);
      expect(find.text('Ajukan Koreksi'), findsOneWidget);
      expect(find.text('Lihat Struk'), findsOneWidget);
      // No change request yet, so no approval UI should render at all.
      expect(find.text('Setujui'), findsNothing);
      expect(find.text('Tolak'), findsNothing);
    },
  );

  testWidgets(
    'HOST sees Approve/Reject for a pending request submitted by someone else',
    (WidgetTester tester) async {
      const requesterId = '66ab12cd34ef56ab78cd90aa';
      final pendingFromOther = _sampleTransactionJson(
        changeRequest: {
          'status': 'PENDING',
          'requestedBy': {'_id': requesterId, 'name': 'Budi Santoso'},
          'reason': 'Salah input service',
          'requestedChanges': {'discountAmount': 10000},
          'requestedAt': '2026-10-18T09:00:00.000Z',
        },
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://grooma.test'))
        ..httpClientAdapter = _FakeTransactionAdapter(pendingFromOther);
      const host = User(
        id: '66hosthosthosthosthost01',
        username: 'owner',
        name: 'Owner',
        role: UserRole.host,
        branch: null,
      );
      final authController = AuthController(AuthService(Dio()))
        ..status = AuthStatus.authenticated
        ..user = host;

      await tester.pumpWidget(
        MaterialApp(
          home: TransactionDetailScreen(
            transactionService: TransactionService(dio),
            changeRequestService: ChangeRequestService(dio),
            authController: authController,
            user: host,
            transactionId: '671234abcd5678ef90123456',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // change-requests doc §5: HOST can't approve/reject their own
      // submission — only someone else's pending request.
      expect(find.text('Setujui'), findsOneWidget);
      expect(find.text('Tolak'), findsOneWidget);
    },
  );

  testWidgets('inventory list always badges low-stock and inactive items, '
      'even though the backend never hides the inactive one', (
    WidgetTester tester,
  ) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://grooma.test'))
      ..httpClientAdapter = _FakeInventoryAdapter();
    const agent = User(
      id: '66ab12cd34ef56ab78cd90aa',
      username: 'budi_agent',
      name: 'Budi Santoso',
      role: UserRole.agent,
      branch: Branch(id: '66ffaa0011223344556677aa', name: 'Cabang Kemang'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: InventoryListScreen(
          inventoryService: InventoryService(dio),
          user: agent,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pomade Matte 100g'), findsOneWidget);
    expect(find.text('Stok Menipis'), findsOneWidget);
    expect(find.text('Shampoo Anti Ketombe'), findsOneWidget);
    expect(find.text('Nonaktif'), findsOneWidget);
  });

  test('recordIn/recordOut/recordAdjustment send the correct '
      'discriminated-union body shape', () async {
    late Map<String, dynamic> captured;
    final dio = Dio(BaseOptions(baseUrl: 'https://grooma.test'))
      ..httpClientAdapter = _CapturingAdapter((body) => captured = body);
    final service = InventoryService(dio);

    await service.recordIn('item1', quantity: 20, reason: 'Restock');
    expect(captured, {
      'movementType': 'IN',
      'quantity': 20,
      'reason': 'Restock',
    });
    expect(captured.containsKey('newQuantity'), isFalse);

    await service.recordOut('item1', quantity: 3, reason: 'Dipakai');
    expect(captured, {
      'movementType': 'OUT',
      'quantity': 3,
      'reason': 'Dipakai',
    });
    expect(captured.containsKey('newQuantity'), isFalse);

    await service.recordAdjustment(
      'item1',
      newQuantity: 15,
      reason: 'Stock take',
    );
    expect(captured, {
      'movementType': 'ADJUSTMENT',
      'newQuantity': 15,
      'reason': 'Stock take',
    });
    // The doc explicitly calls this out as an easy mistake: ADJUSTMENT
    // must never send `quantity` (400 if it does).
    expect(captured.containsKey('quantity'), isFalse);
  });

  test('Customer.fromJson tolerates the 5 privileged fields being entirely '
      'absent, not just null (the AGENT response shape)', () {
    final hostShaped = Customer.fromJson({
      'id': '66aa11bb22cc33dd44ee55ff',
      'customerCode': null,
      'name': 'Andi Wijaya',
      'phone': '6281234567890',
      'customerType': 'REGULAR',
      'loyaltyPoints': 450,
      'lastVisitAt': '2026-10-10T09:00:00.000Z',
      'isActive': true,
      'email': 'andi@example.com',
      'gender': 'MALE',
      'birthDate': '1995-05-20T00:00:00.000Z',
      'address': 'Jl. Kemang Raya No. 10',
      'notes': 'Suka potongan fade',
      'createdAt': '2026-01-10T08:00:00.000Z',
      'updatedAt': '2026-10-10T09:00:00.000Z',
    });
    expect(hostShaped.email, 'andi@example.com');
    expect(hostShaped.gender, CustomerGender.male);
    expect(hostShaped.address, 'Jl. Kemang Raya No. 10');

    // No email/gender/birthDate/address/notes keys at all — this is
    // the literal shape of an AGENT response (doc §0), not
    // `{..., "email": null}`.
    final agentShaped = Customer.fromJson({
      'id': '66aa11bb22cc33dd44ee55ff',
      'customerCode': null,
      'name': 'Andi Wijaya',
      'phone': '6281234567890',
      'customerType': 'REGULAR',
      'loyaltyPoints': 450,
      'lastVisitAt': '2026-10-10T09:00:00.000Z',
      'isActive': true,
      'createdAt': '2026-01-10T08:00:00.000Z',
      'updatedAt': '2026-10-10T09:00:00.000Z',
    });
    expect(agentShaped.name, 'Andi Wijaya');
    expect(agentShaped.loyaltyPoints, 450);
    expect(agentShaped.email, isNull);
    expect(agentShaped.gender, isNull);
    expect(agentShaped.birthDate, isNull);
    expect(agentShaped.address, isNull);
    expect(agentShaped.notes, isNull);
  });

  testWidgets('CustomerDetailScreen shows privileged fields for HOST but hides '
      'them for AGENT, from the same underlying response', (
    WidgetTester tester,
  ) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://grooma.test'))
      ..httpClientAdapter = _FakeCustomerAdapter();
    const host = User(
      id: '66hosthosthosthosthost01',
      username: 'owner',
      name: 'Owner',
      role: UserRole.host,
      branch: null,
    );
    const agent = User(
      id: '66ab12cd34ef56ab78cd90aa',
      username: 'budi_agent',
      name: 'Budi Santoso',
      role: UserRole.agent,
      branch: Branch(id: '66ffaa0011223344556677aa', name: 'Cabang Kemang'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerDetailScreen(
          customerService: CustomerService(dio),
          customerId: '66aa11bb22cc33dd44ee55ff',
          user: host,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Info Tambahan (khusus Host)'), findsOneWidget);
    expect(find.text('andi@example.com'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerDetailScreen(
          customerService: CustomerService(dio),
          customerId: '66aa11bb22cc33dd44ee55ff',
          user: agent,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Info Tambahan (khusus Host)'), findsNothing);
    expect(find.text('andi@example.com'), findsNothing);
  });

  test(
    'Branch/Staff status toggles send an enum string, Service sends a '
    'boolean — the Kelola doc\'s explicitly-called-out inconsistency',
    () async {
      Map<String, dynamic>? branchBody;
      final branchDio = Dio(BaseOptions(baseUrl: 'https://grooma.test'))
        ..httpClientAdapter = _StatusCapturingAdapter(
          (body) => branchBody = body,
          'branch',
          {
            '_id': '66ffaa0011223344556677aa',
            'branchCode': 'KMG',
            'name': 'Cabang Kemang',
            'timezone': 'Asia/Jakarta',
            'status': 'INACTIVE',
            'createdAt': '2026-01-05T04:00:00.000Z',
            'updatedAt': '2026-09-20T07:30:00.000Z',
          },
        );
      await BranchService(branchDio)
          .setStatus('66ffaa0011223344556677aa', BranchStatus.inactive);
      expect(branchBody, {'status': 'INACTIVE'});

      Map<String, dynamic>? staffBody;
      final staffDio = Dio(BaseOptions(baseUrl: 'https://grooma.test'))
        ..httpClientAdapter = _StatusCapturingAdapter(
          (body) => staffBody = body,
          'user',
          {
            'id': '66ab12cd34ef56ab78cd90aa',
            'username': 'budi_agent',
            'name': 'Budi Santoso',
            'role': 'AGENT',
            'status': 'INACTIVE',
            'createdAt': '2026-09-01T10:30:00.000Z',
            'updatedAt': '2026-10-15T14:20:00.000Z',
          },
        );
      await StaffService(staffDio)
          .setStatus('66ab12cd34ef56ab78cd90aa', UserStatus.inactive);
      expect(staffBody, {'status': 'INACTIVE'});

      Map<String, dynamic>? serviceBody;
      final serviceDio = Dio(BaseOptions(baseUrl: 'https://grooma.test'))
        ..httpClientAdapter = _StatusCapturingAdapter(
          (body) => serviceBody = body,
          'service',
          {
            '_id': '66bb22cc33dd44ee55ff6600',
            'serviceCode': 'SRV-001',
            'name': 'Haircut + Styling',
            'price': 100000,
            'durationMinutes': 45,
            'revenueSharing': {'ownerPercentage': 70, 'employeePercentage': 30},
            'isActive': false,
            'createdAt': '2026-01-05T04:00:00.000Z',
            'updatedAt': '2026-09-20T07:30:00.000Z',
          },
        );
      await ServiceCatalogService(serviceDio)
          .setActive('66bb22cc33dd44ee55ff6600', false);
      expect(serviceBody, {'isActive': false});
    },
  );

  test('SubscriptionService.getStatus treats a null subscription as '
      'normal, not an error', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://grooma.test'))
      ..httpClientAdapter = _StatusCapturingAdapter(
        (_) {},
        'subscription',
        null,
      );

    final subscription = await SubscriptionService(dio).getStatus();
    expect(subscription, isNull);
  });

  test('Pagination.fromJson accepts "pages" in place of "totalPages"', () {
    final pagination = Pagination.fromJson({
      'page': 1,
      'limit': 20,
      'total': 4,
      'pages': 1,
    });
    expect(pagination.totalPages, 1);
  });

  test('BranchService.listAll walks every page instead of silently '
      'truncating at the default limit (AUTH doc §2.1.4)', () async {
    final adapter = _PagedBranchAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://grooma.test'))
      ..httpClientAdapter = adapter;

    final branches = await BranchService(dio).listAll();

    expect(branches.map((b) => b.branchCode), ['KMG', 'SCM', 'BSD']);
    expect(adapter.requestCount, 2);
  });
}
