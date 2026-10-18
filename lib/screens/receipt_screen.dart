import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../services/api_exception.dart';
import '../services/transaction_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/message_view.dart';

enum _LoadState { loading, loaded, error }

/// Calls the side-effecting GET /transactions/:id/receipt exactly once,
/// on open — never for preview (transaction doc §6: every call bumps
/// `receipt.printCount`). There's no printer/hardware integration here;
/// this is a read-only preview of what a receipt would contain.
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({
    super.key,
    required this.transactionService,
    required this.transactionId,
  });

  final TransactionService transactionService;
  final String transactionId;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  Transaction? _transaction;

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
      final transaction = await widget.transactionService.receipt(
        widget.transactionId,
      );
      setState(() {
        _transaction = transaction;
        _state = _LoadState.loaded;
      });
    } on ApiException catch (e) {
      setState(() {
        _state = _LoadState.error;
        _errorMessage = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Struk')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadState.error:
        return MessageView(
          icon: Icons.error_outline,
          iconColor: AppColors.error,
          title: 'Gagal memuat struk',
          message: _errorMessage ?? 'Terjadi kesalahan.',
          onRetry: _load,
        );
      case _LoadState.loaded:
        return _buildReceipt(context, _transaction!);
    }
  }

  Widget _buildReceipt(BuildContext context, Transaction t) {
    final branch = t.branch;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    branch.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (branch.address != null)
                    Text(
                      branch.address!,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.secondaryText),
                      textAlign: TextAlign.center,
                    ),
                  if (branch.phone != null)
                    Text(
                      branch.phone!,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.secondaryText),
                    ),
                ],
              ),
            ),
            const Divider(height: 32),
            _row(context, 'Kode Transaksi', t.transactionCode),
            _row(context, 'Tanggal', formatDateTime(t.createdAt)),
            _row(
              context,
              'Customer',
              t.customer?.displayName ?? 'Tanpa customer',
            ),
            const Divider(height: 24),
            _row(context, t.serviceSnapshot.name, formatRupiah(t.subtotal)),
            if (t.discountAmount > 0)
              _row(context, 'Diskon', '-${formatRupiah(t.discountAmount)}'),
            const Divider(height: 24),
            _row(context, 'Total', formatRupiah(t.total), emphasize: true),
            _row(context, 'Metode Bayar', t.paymentMethod.label),
            const SizedBox(height: 16),
            Text(
              'Struk ini telah dicetak/ditampilkan ${t.receipt?.printCount ?? 0} kali.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.secondaryText),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: emphasize ? null : AppColors.secondaryText),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
