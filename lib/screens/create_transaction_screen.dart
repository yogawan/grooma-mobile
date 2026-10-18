import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/auth_controller.dart';
import '../services/change_request_service.dart';
import '../services/transaction_service.dart';
import '../theme/app_colors.dart';
import 'qr_payment_screen.dart';
import 'transaction_detail_screen.dart';

/// AGENT only. No Services/Customers catalog endpoint exists yet in any
/// doc read so far, so `serviceId`/`customerId` are plain manual-entry
/// fields rather than pickers — functional against the real API, but a
/// known rough edge until a catalog module shows up.
class CreateTransactionScreen extends StatefulWidget {
  const CreateTransactionScreen({
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
  State<CreateTransactionScreen> createState() =>
      _CreateTransactionScreenState();
}

class _CreateTransactionScreenState extends State<CreateTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serviceIdController = TextEditingController();
  final _customerIdController = TextEditingController();
  final _discountController = TextEditingController(text: '0');

  PaymentMethod _paymentMethod = PaymentMethod.cash;
  ServiceHourType _hourType = ServiceHourType.regular;

  bool _submitting = false;
  String? _errorMessage;

  // Set only when a QRIS create succeeded but the QR itself failed
  // (transaction doc §1: this is a 201 success, not an error — the
  // sale is already recorded, only the QR generation failed).
  Transaction? _createdWithFailedQr;
  String? _qrError;

  @override
  void dispose() {
    _serviceIdController.dispose();
    _customerIdController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.transactionService.create(
        serviceId: _serviceIdController.text.trim(),
        customerId: _customerIdController.text.trim().isEmpty
            ? null
            : _customerIdController.text.trim(),
        paymentMethod: _paymentMethod,
        discountAmount: num.tryParse(_discountController.text.trim()) ?? 0,
        serviceHourType: _hourType,
      );

      if (!mounted) return;

      if (_paymentMethod == PaymentMethod.qris && result.paymentError != null) {
        setState(() {
          _createdWithFailedQr = result.transaction;
          _qrError = result.paymentError;
          _submitting = false;
        });
        return;
      }

      if (_paymentMethod == PaymentMethod.qris && result.payment != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => QrPaymentScreen(
              transactionService: widget.transactionService,
              payment: result.payment!,
            ),
          ),
        );
        if (mounted) Navigator.of(context).pop(true);
        return;
      }

      // CASH, or QRIS on a SELF_RECORDED deployment (already PAID,
      // identical response shape to CASH — transaction doc §1).
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _submitting = false;
        _errorMessage = e.message;
      });
    }
  }

  Future<void> _retryQr() async {
    final transaction = _createdWithFailedQr!;
    setState(() => _submitting = true);
    try {
      final payment = await widget.transactionService.createOrRetryQris(
        transaction.id,
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
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _submitting = false;
        _qrError = e.message;
      });
    }
  }

  void _viewTransactionInstead() {
    final transaction = _createdWithFailedQr!;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(
          transactionService: widget.transactionService,
          changeRequestService: widget.changeRequestService,
          authController: widget.authController,
          user: widget.user,
          transactionId: transaction.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi Baru')),
      body: _createdWithFailedQr != null
          ? _buildQrFailed(context)
          : _buildForm(context),
    );
  }

  Widget _buildQrFailed(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_2, size: 48, color: AppColors.warning),
            const SizedBox(height: 16),
            Text(
              'Transaksi tersimpan, tapi QR gagal dibuat',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _qrError ?? 'Terjadi kesalahan saat membuat QR.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.secondaryText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _retryQr,
              child: const Text('Coba Buat QR Lagi'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _submitting ? null : _viewTransactionInstead,
              child: const Text('Lihat Transaksi Saja'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.secondarySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Belum ada katalog layanan/customer di app ini — isi Service ID '
                '(dan Customer ID bila ada) secara manual.',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _serviceIdController,
              decoration: const InputDecoration(labelText: 'Service ID'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Service ID wajib diisi'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _customerIdController,
              decoration: const InputDecoration(
                labelText: 'Customer ID (opsional)',
              ),
            ),
            const SizedBox(height: 16),
            Text('Metode Bayar', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<PaymentMethod>(
              segments: const [
                ButtonSegment(value: PaymentMethod.cash, label: Text('Cash')),
                ButtonSegment(value: PaymentMethod.qris, label: Text('QRIS')),
              ],
              selected: {_paymentMethod},
              onSelectionChanged: (s) =>
                  setState(() => _paymentMethod = s.first),
            ),
            const SizedBox(height: 16),
            Text('Jenis Jam', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<ServiceHourType>(
              segments: const [
                ButtonSegment(
                  value: ServiceHourType.regular,
                  label: Text('Reguler'),
                ),
                ButtonSegment(
                  value: ServiceHourType.overtime,
                  label: Text('Lembur'),
                ),
              ],
              selected: {_hourType},
              onSelectionChanged: (s) => setState(() => _hourType = s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _discountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: false,
              ),
              decoration: const InputDecoration(labelText: 'Diskon (Rp)'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                final parsed = num.tryParse(value.trim());
                if (parsed == null || parsed < 0) return 'Diskon tidak valid';
                return null;
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : const Text('Buat Transaksi'),
            ),
          ],
        ),
      ),
    );
  }
}
