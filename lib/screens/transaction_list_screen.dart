import 'dart:async';

import 'package:flutter/material.dart';

import '../models/pagination.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/auth_controller.dart';
import '../services/change_request_service.dart';
import '../services/customer_service.dart';
import '../services/service_catalog_service.dart';
import '../services/transaction_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../utils/status_colors.dart';
import '../widgets/message_view.dart';
import '../widgets/status_badge.dart';
import 'change_request_queue_screen.dart';
import 'create_transaction_screen.dart';
import 'transaction_detail_screen.dart';

enum _LoadState { loading, loaded, locked, error }

/// Shared list for both roles — HOST sees every branch, AGENT
/// automatically sees only their own branch's transactions, both
/// resolved server-side from the session (transaction doc §2). HOST's
/// `branchId`/`agentId` filters and the `from`/`to`/`paymentStatus`
/// filters are deferred for this simple first pass, same as the
/// dashboard/profile modules before it.
///
/// Persetujuan Koreksi (HOST-only) lives here as a sub-page per
/// docs/MOBILE-BOTTOM-NAVBAR.md, rather than as its own nav slot.
class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({
    super.key,
    required this.transactionService,
    required this.changeRequestService,
    required this.authController,
    required this.user,
    this.customerService,
    this.serviceCatalogService,
    this.onChangeRequestsReviewed,
  });

  final TransactionService transactionService;
  final ChangeRequestService changeRequestService;
  final AuthController authController;
  final User user;

  // Only needed for the AGENT "Transaksi Baru" flow (HOST can't create
  // transactions at all — transaction doc §0 — and never passes these).
  // Nullable here rather than required so HOST's call site doesn't have
  // to thread services it will never use.
  final CustomerService? customerService;
  final ServiceCatalogService? serviceCatalogService;

  /// Notifies the parent (bottom-nav badge count) after the Persetujuan
  /// sub-page is closed, since approving/rejecting there can change it.
  final VoidCallback? onChangeRequestsReviewed;

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  static const _statusFilters = [
    null,
    TransactionStatus.pending,
    TransactionStatus.completed,
    TransactionStatus.cancelled,
  ];

  final _searchController = TextEditingController();
  TransactionStatus? _statusFilter;
  int _page = 1;
  Timer? _searchDebounce;

  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  List<Transaction> _transactions = const [];
  Pagination? _pagination;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _state = _LoadState.loading;
      _errorMessage = null;
    });
    try {
      final result = await widget.transactionService.list(
        page: _page,
        search: _searchController.text.trim(),
        transactionStatus: _statusFilter,
      );
      setState(() {
        _transactions = result.transactions;
        _pagination = result.pagination;
        _state = _LoadState.loaded;
      });
    } on ApiException catch (e) {
      // HOST (never AGENT — transaction doc §0 EXEMPT_AGENT) can 402 here
      // if the subscription lapsed.
      setState(() {
        _state = e.code == 'PAYMENT_REQUIRED'
            ? _LoadState.locked
            : _LoadState.error;
        _errorMessage = e.message;
      });
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _page = 1;
      _load();
    });
  }

  void _setStatusFilter(TransactionStatus? status) {
    setState(() => _statusFilter = status);
    _page = 1;
    _load();
  }

  void _changePage(int delta) {
    setState(() => _page += delta);
    _load();
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateTransactionScreen(
          transactionService: widget.transactionService,
          changeRequestService: widget.changeRequestService,
          authController: widget.authController,
          user: widget.user,
          customerService: widget.customerService!,
          serviceCatalogService: widget.serviceCatalogService!,
        ),
      ),
    );
    if (created == true) _load();
  }

  Future<void> _openDetail(String transactionId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(
          transactionService: widget.transactionService,
          changeRequestService: widget.changeRequestService,
          authController: widget.authController,
          user: widget.user,
          transactionId: transactionId,
        ),
      ),
    );
    _load();
  }

  Future<void> _openChangeRequestQueue() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeRequestQueueScreen(
          transactionService: widget.transactionService,
          changeRequestService: widget.changeRequestService,
          authController: widget.authController,
          user: widget.user,
        ),
      ),
    );
    _load();
    widget.onChangeRequestsReviewed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isAgent = widget.user.role == UserRole.agent;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi'),
        actions: [
          if (!isAgent)
            IconButton(
              icon: const Icon(Icons.pending_actions_outlined),
              tooltip: 'Persetujuan Koreksi',
              onPressed: _openChangeRequestQueue,
            ),
        ],
      ),
      floatingActionButton: isAgent
          ? FloatingActionButton(
              onPressed: _openCreate,
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          _buildFilters(context),
          Expanded(child: _buildBody(context)),
          if (_pagination != null) _buildPager(context, _pagination!),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Cari kode transaksi',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _statusFilters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final status = _statusFilters[index];
                final selected = _statusFilter == status;
                return ChoiceChip(
                  label: Text(status?.label ?? 'Semua'),
                  selected: selected,
                  onSelected: (_) => _setStatusFilter(status),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadState.locked:
        return MessageView(
          icon: Icons.lock_outline,
          iconColor: AppColors.warning,
          title: 'Transaksi terkunci',
          message: _errorMessage ?? 'Subscription tidak aktif. Hubungi pemilik untuk memperbarui langganan.',
          onRetry: _load,
        );
      case _LoadState.error:
        return MessageView(
          icon: Icons.error_outline,
          iconColor: AppColors.error,
          title: 'Gagal memuat transaksi',
          message: _errorMessage ?? 'Terjadi kesalahan.',
          onRetry: _load,
        );
      case _LoadState.loaded:
        if (_transactions.isEmpty) {
          return const Center(child: Text('Belum ada transaksi.'));
        }
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView.separated(
            itemCount: _transactions.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, thickness: 1, color: AppColors.border),
            itemBuilder: (context, index) =>
                _buildRow(context, _transactions[index]),
          ),
        );
    }
  }

  Widget _buildRow(BuildContext context, Transaction transaction) {
    final isHost = widget.user.role == UserRole.host;
    final subtitleParts = [
      transaction.customer?.displayName ?? 'Tanpa customer',
      if (isHost) transaction.agent.displayName,
    ];

    return ListTile(
      onTap: () => _openDetail(transaction.id),
      title: Text(transaction.transactionCode),
      subtitle: Text(subtitleParts.join(' • ')),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatRupiah(transaction.total),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          StatusBadge(
            label: transaction.transactionStatus.label,
            color: transactionStatusColor(transaction.transactionStatus),
          ),
        ],
      ),
    );
  }

  Widget _buildPager(BuildContext context, Pagination pagination) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: pagination.page > 1 ? () => _changePage(-1) : null,
            child: const Text('Sebelumnya'),
          ),
          Text(
            'Halaman ${pagination.page} dari ${pagination.totalPages == 0 ? 1 : pagination.totalPages}',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.secondaryText),
          ),
          TextButton(
            onPressed: pagination.page < pagination.totalPages
                ? () => _changePage(1)
                : null,
            child: const Text('Berikutnya'),
          ),
        ],
      ),
    );
  }
}
