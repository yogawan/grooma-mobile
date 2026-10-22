import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/pagination.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/auth_controller.dart';
import '../services/change_request_service.dart';
import '../services/transaction_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/message_view.dart';
import 'transaction_detail_screen.dart';

enum _LoadState { loading, loaded, locked, error }

/// HOST-only inbox of PENDING change requests across every branch
/// (change-requests doc §3) — tapping an item opens the normal
/// TransactionDetailScreen, which already renders Approve/Reject
/// inline when `changeRequest.status == PENDING`, so this screen is
/// just a filtered entry point, not a second detail UI.
class ChangeRequestQueueScreen extends StatefulWidget {
  const ChangeRequestQueueScreen({
    super.key,
    required this.transactionService,
    required this.changeRequestService,
    required this.authController,
    required this.user,
  });

  final TransactionService transactionService;
  final ChangeRequestService changeRequestService;
  final AuthController authController;
  final User user;

  @override
  State<ChangeRequestQueueScreen> createState() =>
      _ChangeRequestQueueScreenState();
}

class _ChangeRequestQueueScreenState extends State<ChangeRequestQueueScreen> {
  int _page = 1;
  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  List<Transaction> _transactions = const [];
  Pagination? _pagination;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _state = _LoadState.loading;
      _errorMessage = null;
    });
    try {
      final result = await widget.changeRequestService.listPending(page: _page);
      setState(() {
        _transactions = result.transactions;
        _pagination = result.pagination;
        _state = _LoadState.loaded;
      });
    } on ApiException catch (e) {
      // ENFORCED for both roles here (change-requests doc §1) — unlike
      // TransactionListScreen, this applies even though the viewer is
      // always HOST on this particular screen.
      setState(() {
        _state = e.code == 'PAYMENT_REQUIRED'
            ? _LoadState.locked
            : _LoadState.error;
        _errorMessage = e.message;
      });
    }
  }

  void _changePage(int delta) {
    setState(() => _page += delta);
    _load();
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
    // Always back to page 1 here, not whatever page we were on — an
    // approve/reject on the detail screen (which this push can't tell
    // us happened or not) removes one row from the PENDING queue, so
    // staying on e.g. page 2 risks reloading a page that's now short or
    // empty (change-requests doc §3: "jangan mempertahankan posisi
    // halaman").
    _page = 1;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Persetujuan Koreksi')),
      body: Column(
        children: [
          Expanded(child: _buildBody(context)),
          if (_pagination != null) _buildPager(context, _pagination!),
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
          icon: LucideIcons.lock,
          iconColor: AppColors.warning,
          title: 'Terkunci',
          message: _errorMessage ?? 'Subscription tidak aktif. Hubungi pemilik untuk memperbarui langganan.',
          onRetry: _load,
        );
      case _LoadState.error:
        return MessageView(
          icon: LucideIcons.circleAlert,
          iconColor: AppColors.error,
          title: 'Gagal memuat antrean',
          message: _errorMessage ?? 'Terjadi kesalahan.',
          onRetry: _load,
        );
      case _LoadState.loaded:
        if (_transactions.isEmpty) {
          return const Center(child: Text('Tidak ada pengajuan menunggu.'));
        }
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView.separated(
            itemCount: _transactions.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _buildRow(context, _transactions[index]),
          ),
        );
    }
  }

  Widget _buildRow(BuildContext context, Transaction transaction) {
    final cr = transaction.changeRequest;
    return ListTile(
      onTap: () => _openDetail(transaction.id),
      title: Text(transaction.transactionCode),
      subtitle: Text(
        '${transaction.branch.displayName} • Diajukan oleh ${cr.requestedBy?.displayName ?? '-'}',
      ),
      trailing: Text(
        cr.requestedAt == null ? '' : formatDateTime(cr.requestedAt!),
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: AppColors.secondaryText),
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
