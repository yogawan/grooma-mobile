import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/payment.dart';
import '../services/api_exception.dart';
import '../services/transaction_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';

/// Polls GET /payments/:id every ~4s until status leaves PENDING or
/// `expiresAt` passes (transaction doc §7.2 — there is no push/webhook
/// to the app, polling is the only way to know a payment landed).
class QrPaymentScreen extends StatefulWidget {
  const QrPaymentScreen({
    super.key,
    required this.transactionService,
    required this.payment,
  });

  final TransactionService transactionService;
  final Payment payment;

  @override
  State<QrPaymentScreen> createState() => _QrPaymentScreenState();
}

class _QrPaymentScreenState extends State<QrPaymentScreen> {
  late Payment _payment;
  Timer? _pollTimer;
  bool _regenerating = false;
  String? _errorMessage;

  bool get _locallyExpired =>
      _payment.expiresAt != null && DateTime.now().isAfter(_payment.expiresAt!);

  @override
  void initState() {
    super.initState();
    _payment = widget.payment;
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  Future<void> _poll() async {
    if (_payment.status != PaymentGatewayStatus.pending || _locallyExpired) {
      _pollTimer?.cancel();
      return;
    }
    try {
      final updated = await widget.transactionService.getPayment(_payment.id);
      if (!mounted) return;
      setState(() => _payment = updated);
      if (updated.status != PaymentGatewayStatus.pending) {
        _pollTimer?.cancel();
      }
    } on ApiException {
      // Transient poll failure — just try again on the next tick rather
      // than surfacing an error for a background refresh.
    }
  }

  Future<void> _regenerate() async {
    setState(() {
      _regenerating = true;
      _errorMessage = null;
    });
    try {
      final payment = await widget.transactionService.createOrRetryQris(
        _payment.transactionId,
      );
      setState(() {
        _payment = payment;
        _regenerating = false;
      });
      _startPolling();
    } on ApiException catch (e) {
      setState(() {
        _regenerating = false;
        _errorMessage = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran QRIS')),
      body: Center(child: _buildContent(context)),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_payment.status == PaymentGatewayStatus.paid) {
      return _buildTerminal(
        context,
        icon: LucideIcons.circleCheck,
        color: AppColors.success,
        title: 'Pembayaran Berhasil',
        subtitle: formatRupiah(_payment.grossAmount),
        buttonLabel: 'Selesai',
        onPressed: () => Navigator.of(context).pop(),
      );
    }

    final expired =
        _payment.status == PaymentGatewayStatus.expired || _locallyExpired;
    if (expired) {
      return _buildTerminal(
        context,
        icon: LucideIcons.timerOff,
        color: AppColors.error,
        title: 'QR Kedaluwarsa',
        subtitle: 'Buat QR baru untuk melanjutkan pembayaran.',
        buttonLabel: _regenerating ? null : 'Buat QR Baru',
        onPressed: _regenerating ? null : _regenerate,
        extra: _errorMessage == null
            ? null
            : Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error),
              ),
      );
    }

    if (_payment.status == PaymentGatewayStatus.failed ||
        _payment.status == PaymentGatewayStatus.refunded) {
      return _buildTerminal(
        context,
        icon: LucideIcons.circleAlert,
        color: AppColors.error,
        title: _payment.status.label,
        subtitle: formatRupiah(_payment.grossAmount),
        buttonLabel: 'Kembali',
        onPressed: () => Navigator.of(context).pop(),
      );
    }

    return _buildPending(context);
  }

  Widget _buildPending(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatRupiah(_payment.grossAmount),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          if (_payment.qrCodeUrl != null)
            Image.network(
              _payment.qrCodeUrl!,
              width: 240,
              height: 240,
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                width: 240,
                height: 240,
                child: Center(child: Icon(LucideIcons.qrCode, size: 96)),
              ),
            )
          else
            const SizedBox(
              width: 240,
              height: 240,
              child: Center(child: Icon(LucideIcons.qrCode, size: 96)),
            ),
          const SizedBox(height: 16),
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 12),
          Text(
            'Menunggu pembayaran...',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.secondaryText),
          ),
          if (_payment.expiresAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Kedaluwarsa pada ${formatDateTime(_payment.expiresAt!)}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.secondaryText),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTerminal(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String? buttonLabel,
    required VoidCallback? onPressed,
    Widget? extra,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: color),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.secondaryText),
          ),
          if (extra != null) ...[const SizedBox(height: 8), extra],
          const SizedBox(height: 24),
          if (buttonLabel != null)
            FilledButton(onPressed: onPressed, child: Text(buttonLabel))
          else
            const CircularProgressIndicator(),
        ],
      ),
    );
  }
}
