import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/customer.dart';
import '../models/service_item.dart';
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
import '../widgets/searchable_picker.dart';
import 'qr_payment_screen.dart';
import 'transaction_detail_screen.dart';

/// AGENT only. Service and Customer are picked via a searchable bottom
/// sheet instead of typed in by id. Service has no server-side search
/// (Kelola doc §3.1), so the picker fetches the whole active catalog
/// once via [ServiceCatalogService.listAll] and filters in-memory;
/// Customer narrows through the live `/customers` search instead
/// (customer doc §2), since that base can be much bigger.
class CreateTransactionScreen extends StatefulWidget {
  const CreateTransactionScreen({
    super.key,
    required this.transactionService,
    required this.changeRequestService,
    required this.customerService,
    required this.serviceCatalogService,
    required this.authController,
    required this.user,
  });

  final TransactionService transactionService;
  final ChangeRequestService changeRequestService;
  final CustomerService customerService;
  final ServiceCatalogService serviceCatalogService;
  final AuthController authController;
  final User user;

  @override
  State<CreateTransactionScreen> createState() =>
      _CreateTransactionScreenState();
}

class _CreateTransactionScreenState extends State<CreateTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _discountController = TextEditingController(text: '0');

  ServiceItem? _selectedService;
  Customer? _selectedCustomer;
  // Fetched once (lazily) then reused for every subsequent picker open,
  // since the catalog doesn't change mid-form and refetching on every
  // tap would just be a slower picker for no benefit.
  List<ServiceItem>? _allServices;

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
    _discountController.dispose();
    super.dispose();
  }

  Future<List<ServiceItem>> _searchServices(String query) async {
    _allServices ??= await widget.serviceCatalogService.listAll();
    if (query.isEmpty) return _allServices!;
    final q = query.toLowerCase();
    return _allServices!
        .where(
          (s) =>
              s.name.toLowerCase().contains(q) ||
              s.serviceCode.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<List<Customer>> _searchCustomers(String query) async {
    final result = await widget.customerService.search(
      search: query.isEmpty ? null : query,
    );
    return result.customers;
  }

  Future<void> _pickService() async {
    final picked = await showSearchablePicker<ServiceItem>(
      context: context,
      title: 'Pilih Layanan',
      hintText: 'Cari nama atau kode layanan',
      onSearch: _searchServices,
      labelOf: (s) => s.name,
      subtitleOf: (s) => formatRupiah(s.price),
    );
    if (picked != null) setState(() => _selectedService = picked);
  }

  Future<void> _pickCustomer() async {
    final picked = await showSearchablePicker<Customer>(
      context: context,
      title: 'Pilih Customer',
      hintText: 'Cari nama atau nomor HP',
      onSearch: _searchCustomers,
      labelOf: (c) => c.name,
      subtitleOf: (c) => c.phone,
    );
    if (picked != null) setState(() => _selectedCustomer = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedService == null) {
      setState(() => _errorMessage = 'Pilih layanan terlebih dahulu.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.transactionService.create(
        serviceId: _selectedService!.id,
        customerId: _selectedCustomer?.id,
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
            const Icon(LucideIcons.qrCode, size: 48, color: AppColors.warning),
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
            _buildPickerTile(
              label: 'Service',
              placeholder: 'Pilih layanan',
              value: _selectedService == null
                  ? null
                  : '${_selectedService!.name} • ${formatRupiah(_selectedService!.price)}',
              onTap: _pickService,
            ),
            const SizedBox(height: 16),
            _buildPickerTile(
              label: 'Customer (opsional)',
              placeholder: 'Pilih customer',
              value: _selectedCustomer?.name,
              onTap: _pickCustomer,
              onClear: _selectedCustomer == null
                  ? null
                  : () => setState(() => _selectedCustomer = null),
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

  Widget _buildPickerTile({
    required String label,
    required String placeholder,
    required String? value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: onClear != null
              ? IconButton(icon: const Icon(LucideIcons.x), onPressed: onClear)
              : const Icon(LucideIcons.chevronDown),
        ),
        child: Text(
          value ?? placeholder,
          overflow: TextOverflow.ellipsis,
          style: value == null
              ? TextStyle(color: Theme.of(context).hintColor)
              : null,
        ),
      ),
    );
  }
}
