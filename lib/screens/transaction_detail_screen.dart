import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/auth_controller.dart';
import '../services/change_request_service.dart';
import '../services/transaction_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../utils/status_colors.dart';
import '../widgets/message_view.dart';
import '../widgets/status_badge.dart';
import 'change_request_form_screen.dart';
import 'qr_payment_screen.dart';
import 'receipt_screen.dart';

enum _LoadState { loading, loaded, locked, error }

/// Single detail screen reused for both the normal "view a transaction"
/// flow and the HOST approval flow for its embedded change request —
/// which actions are visible is purely a function of role + current
/// transaction state, computed below, not two separate screens.
class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({
    super.key,
    required this.transactionService,
    required this.changeRequestService,
    required this.authController,
    required this.user,
    required this.transactionId,
  });

  final TransactionService transactionService;
  final ChangeRequestService changeRequestService;
  final AuthController authController;
  final User user;
  final String transactionId;

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  Transaction? _transaction;
  bool _actionInProgress = false;

  bool get _isHost => widget.user.role == UserRole.host;
  bool get _isAgent => widget.user.role == UserRole.agent;

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
      final transaction = await widget.transactionService.detail(
        widget.transactionId,
      );
      setState(() {
        _transaction = transaction;
        _state = _LoadState.loaded;
      });
    } on ApiException catch (e) {
      setState(() {
        _state = e.code == 'PAYMENT_REQUIRED'
            ? _LoadState.locked
            : _LoadState.error;
        _errorMessage = e.message;
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _actionInProgress = true);
    try {
      await action();
    } on ApiException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _complete() => _runAction(() async {
    final updated = await widget.transactionService.complete(
      widget.transactionId,
    );
    setState(() => _transaction = updated);
    _showMessage('Transaksi diselesaikan.');
  });

  Future<void> _cancel() async {
    final transaction = _transaction!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan transaksi?'),
        content: Text(
          transaction.paymentStatus == TransactionPaymentStatus.paid
              ? 'Transaksi ini sudah dibayar. Membatalkan TIDAK mengembalikan dana secara otomatis — status bayar akan tetap Lunas.'
              : 'Transaksi ini akan dibatalkan dan tidak bisa diproses lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _runAction(() async {
      final updated = await widget.transactionService.cancel(
        widget.transactionId,
      );
      setState(() => _transaction = updated);
      _showMessage('Transaksi dibatalkan.');
    });
  }

  Future<void> _payQris() => _runAction(() async {
    try {
      final payment = await widget.transactionService.createOrRetryQris(
        widget.transactionId,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QrPaymentScreen(
            transactionService: widget.transactionService,
            payment: payment,
          ),
        ),
      );
      _load();
    } on ApiException catch (e) {
      if (e.code == 'CONFLICT') {
        // transaction doc §7.1: a 409 here means a still-valid QR already
        // exists, but there's no endpoint to look an existing payment up
        // by transaction id — nothing to show except "wait it out".
        _showMessage(
          'Masih ada QR aktif untuk transaksi ini, coba lagi nanti.',
        );
      } else {
        rethrow;
      }
    }
  });

  Future<void> _openChangeRequestForm() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChangeRequestFormScreen(
          changeRequestService: widget.changeRequestService,
          transactionId: widget.transactionId,
        ),
      ),
    );
    if (submitted == true) _load();
  }

  Future<void> _openReceipt() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReceiptScreen(
          transactionService: widget.transactionService,
          transactionId: widget.transactionId,
        ),
      ),
    );
  }

  Future<void> _approve() async {
    final result =
        await showDialog<({String reviewNote, String approvalReference})>(
          context: context,
          builder: (context) => _ReviewDialog(
            title: 'Setujui Pengajuan',
            noteLabel: 'Catatan (opsional)',
            confirmLabel: 'Setujui',
            noteRequired: false,
            showReference: true,
          ),
        );
    if (result == null) return;

    await _runAction(() async {
      try {
        final updated = await widget.changeRequestService.approve(
          widget.transactionId,
          reviewNote: result.reviewNote.isEmpty ? null : result.reviewNote,
          approvalReference: result.approvalReference.isEmpty
              ? null
              : result.approvalReference,
        );
        setState(() => _transaction = updated);
        _showMessage('Pengajuan disetujui.');
      } on ApiException catch (e) {
        if (e.code == 'BUSINESS_RULE_VIOLATION') {
          // change-requests doc §5: a 422 here leaves the request
          // PENDING rather than failing it — point the HOST at Reject
          // as the explicit way out instead of a dead-end error.
          _showMessage(
            '${e.message} Pengajuan masih berstatus menunggu — gunakan Tolak jika tidak bisa disetujui.',
          );
          _load();
        } else {
          rethrow;
        }
      }
    });
  }

  Future<void> _reject() async {
    final result =
        await showDialog<({String reviewNote, String approvalReference})>(
          context: context,
          builder: (context) => _ReviewDialog(
            title: 'Tolak Pengajuan',
            noteLabel: 'Alasan penolakan',
            confirmLabel: 'Tolak',
            noteRequired: true,
            showReference: false,
          ),
        );
    if (result == null) return;

    await _runAction(() async {
      final updated = await widget.changeRequestService.reject(
        widget.transactionId,
        reviewNote: result.reviewNote,
      );
      setState(() => _transaction = updated);
      _showMessage('Pengajuan ditolak.');
    });
  }

  bool _canComplete(Transaction t) =>
      _isAgent && t.transactionStatus == TransactionStatus.pending;

  bool _canCancel(Transaction t) =>
      t.transactionStatus == TransactionStatus.pending;

  bool _canSubmitChangeRequest(Transaction t) =>
      t.transactionStatus != TransactionStatus.cancelled &&
      t.changeRequest.status != ChangeRequestStatus.pending;

  bool _canPayQris(Transaction t) =>
      t.paymentMethod == PaymentMethod.qris &&
      t.paymentStatus == TransactionPaymentStatus.pending;

  bool _pendingReviewByOthers(Transaction t) =>
      _isHost &&
      t.changeRequest.status == ChangeRequestStatus.pending &&
      t.changeRequest.requestedBy?.id != widget.user.id;

  bool _pendingButOwnRequest(Transaction t) =>
      _isHost &&
      t.changeRequest.status == ChangeRequestStatus.pending &&
      t.changeRequest.requestedBy?.id == widget.user.id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Transaksi')),
      body: _buildBody(context),
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
        return _buildLoaded(context, _transaction!);
    }
  }

  Widget _buildLoaded(BuildContext context, Transaction t) {
    return AbsorbPointer(
      absorbing: _actionInProgress,
      child: Opacity(
        opacity: _actionInProgress ? 0.6 : 1,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, t),
              const SizedBox(height: 16),
              _buildInfoCard(context, t),
              const SizedBox(height: 16),
              _buildActions(context, t),
              if (t.changeRequest.status != ChangeRequestStatus.none) ...[
                const SizedBox(height: 16),
                _buildChangeRequestCard(context, t),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Transaction t) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.transactionCode,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                formatDateTime(t.createdAt),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
        StatusBadge(
          label: t.transactionStatus.label,
          color: transactionStatusColor(t.transactionStatus),
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, Transaction t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(context, 'Layanan', t.serviceSnapshot.name),
          _row(context, 'Jenis Jam', t.serviceHourType.label),
          _row(
            context,
            'Customer',
            t.customer?.displayName ?? 'Tanpa customer',
          ),
          if (_isHost) _row(context, 'Agent', t.agent.displayName),
          if (_isHost) _row(context, 'Cabang', t.branch.displayName),
          const Divider(height: 24),
          _row(context, 'Subtotal', formatRupiah(t.subtotal)),
          _row(context, 'Diskon', formatRupiah(t.discountAmount)),
          _row(context, 'Total', formatRupiah(t.total), emphasize: true),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t.paymentMethod.label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              StatusBadge(
                label: t.paymentStatus.label,
                color: paymentStatusColor(t.paymentStatus),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _row(context, 'Poin Didapat', '${t.pointsEarned}'),
        ],
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
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.secondaryText),
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

  Widget _buildActions(BuildContext context, Transaction t) {
    final buttons = <Widget>[];

    if (_canPayQris(t)) {
      buttons.add(
        FilledButton.icon(
          onPressed: _payQris,
          icon: const Icon(Icons.qr_code),
          label: const Text('Bayar QRIS'),
        ),
      );
    }
    if (_canComplete(t)) {
      buttons.add(
        FilledButton.icon(
          onPressed: _complete,
          icon: const Icon(Icons.check),
          label: const Text('Selesaikan'),
        ),
      );
    }
    if (_canCancel(t)) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: _cancel,
          icon: const Icon(Icons.close),
          label: const Text('Batalkan'),
        ),
      );
    }
    if (_canSubmitChangeRequest(t)) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: _openChangeRequestForm,
          icon: const Icon(Icons.edit_note),
          label: const Text('Ajukan Koreksi'),
        ),
      );
    }
    buttons.add(
      OutlinedButton.icon(
        onPressed: _openReceipt,
        icon: const Icon(Icons.receipt_long),
        label: const Text('Lihat Struk'),
      ),
    );

    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }

  Widget _buildChangeRequestCard(BuildContext context, Transaction t) {
    final cr = t.changeRequest;
    final changes = cr.requestedChanges;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pengajuan Koreksi',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              StatusBadge(
                label: cr.status.label,
                color: changeRequestStatusColor(cr.status),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (cr.reason != null) _row(context, 'Alasan', cr.reason!),
          if (changes?.serviceId != null)
            _row(context, 'Service ID baru', changes!.serviceId!),
          if (changes?.customerId != null)
            _row(context, 'Customer ID baru', changes!.customerId!),
          if (changes?.discountAmount != null)
            _row(
              context,
              'Diskon baru',
              formatRupiah(changes!.discountAmount!),
            ),
          if (changes?.serviceHourType != null)
            _row(context, 'Jenis jam baru', changes!.serviceHourType!.label),
          if (cr.requestedBy != null)
            _row(context, 'Diajukan oleh', cr.requestedBy!.displayName),
          if (cr.requestedAt != null)
            _row(context, 'Diajukan pada', formatDateTime(cr.requestedAt!)),
          if (cr.reviewedBy != null) ...[
            const Divider(height: 24),
            _row(context, 'Ditinjau oleh', cr.reviewedBy!.displayName),
            if (cr.reviewNote != null) _row(context, 'Catatan', cr.reviewNote!),
            if (cr.reviewedAt != null)
              _row(context, 'Ditinjau pada', formatDateTime(cr.reviewedAt!)),
          ],
          if (_pendingButOwnRequest(t)) ...[
            const SizedBox(height: 12),
            Text(
              'Anda tidak bisa menyetujui/menolak pengajuan sendiri.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.secondaryText),
            ),
          ],
          if (_pendingReviewByOthers(t)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reject,
                    child: const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _approve,
                    child: const Text('Setujui'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({
    required this.title,
    required this.noteLabel,
    required this.confirmLabel,
    required this.noteRequired,
    required this.showReference,
  });

  final String title;
  final String noteLabel;
  final String confirmLabel;
  final bool noteRequired;
  final bool showReference;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _referenceController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop((
      reviewNote: _noteController.text.trim(),
      approvalReference: _referenceController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(labelText: widget.noteLabel),
              validator: (value) {
                if (!widget.noteRequired) return null;
                return (value == null || value.trim().isEmpty)
                    ? 'Wajib diisi'
                    : null;
              },
            ),
            if (widget.showReference) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'Referensi (opsional)',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
