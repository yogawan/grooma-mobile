import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/customer_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/message_view.dart';
import '../widgets/status_badge.dart';
import 'customer_form_screen.dart';

enum _LoadState { loading, loaded, error }

/// Privileged fields (email/gender/birthDate/address/notes) are shown
/// only when the viewer is HOST — gated by [User.role], not by
/// null-checking the parsed value, since for AGENT those fields are
/// structurally absent from every response regardless of whether
/// they're actually set (customer doc §0).
class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({
    super.key,
    required this.customerService,
    required this.customerId,
    required this.user,
  });

  final CustomerService customerService;
  final String customerId;
  final User user;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  Customer? _customer;
  bool _actionInProgress = false;

  bool get _isHost => widget.user.role == UserRole.host;

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
      final customer = await widget.customerService.detail(widget.customerId);
      setState(() {
        _customer = customer;
        _state = _LoadState.loaded;
      });
    } on ApiException catch (e) {
      setState(() {
        _state = _LoadState.error;
        _errorMessage = e.message;
      });
    }
  }

  Future<void> _openEdit() async {
    final updated = await Navigator.of(context).push<Customer>(
      MaterialPageRoute(
        builder: (_) => CustomerFormScreen(
          customerService: widget.customerService,
          existingCustomer: _customer,
          isHost: _isHost,
        ),
      ),
    );
    if (updated != null) setState(() => _customer = updated);
  }

  Future<void> _toggleActive() async {
    final customer = _customer!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          customer.isActive ? 'Nonaktifkan customer?' : 'Aktifkan customer?',
        ),
        content: Text(
          customer.isActive
              ? 'Customer tidak bisa dipakai untuk transaksi baru selama nonaktif. Riwayat lama tidak berubah.'
              : 'Customer akan bisa dipakai lagi untuk transaksi baru.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(customer.isActive ? 'Nonaktifkan' : 'Aktifkan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _actionInProgress = true);
    try {
      final updated = await widget.customerService.setActive(
        customer.id,
        isActive: !customer.isActive,
      );
      setState(() {
        _customer = updated;
        _actionInProgress = false;
      });
    } on ApiException catch (e) {
      setState(() => _actionInProgress = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Customer')),
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
          title: 'Gagal memuat customer',
          message: _errorMessage ?? 'Terjadi kesalahan.',
          onRetry: _load,
        );
      case _LoadState.loaded:
        return _buildLoaded(context, _customer!);
    }
  }

  Widget _buildLoaded(BuildContext context, Customer customer) {
    return AbsorbPointer(
      absorbing: _actionInProgress,
      child: Opacity(
        opacity: _actionInProgress ? 0.6 : 1,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, customer),
              const SizedBox(height: 16),
              _buildInfoCard(context, customer),
              if (_isHost) ...[
                const SizedBox(height: 16),
                _buildPrivilegedCard(context, customer),
              ],
              const SizedBox(height: 16),
              _buildActions(context, customer),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Customer customer) {
    return Row(
      children: [
        Expanded(
          child: Text(
            customer.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (!customer.isActive)
          const StatusBadge(label: 'Nonaktif', color: AppColors.secondaryText),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, Customer customer) {
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
          _row(context, 'Nomor HP', customer.phone ?? '-'),
          _row(context, 'Poin Loyalti', '${customer.loyaltyPoints}'),
          _row(
            context,
            'Kunjungan Terakhir',
            customer.lastVisitAt == null
                ? 'Belum pernah'
                : formatDateTime(customer.lastVisitAt!),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivilegedCard(BuildContext context, Customer customer) {
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
          Text(
            'Info Tambahan (khusus Host)',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          _row(context, 'Email', customer.email ?? '-'),
          _row(context, 'Jenis Kelamin', customer.gender?.label ?? '-'),
          _row(
            context,
            'Tanggal Lahir',
            customer.birthDate == null ? '-' : formatDate(customer.birthDate!),
          ),
          _row(context, 'Alamat', customer.address ?? '-'),
          _row(context, 'Catatan', customer.notes ?? '-'),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
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
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, Customer customer) {
    final buttons = <Widget>[
      OutlinedButton.icon(
        onPressed: _openEdit,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Edit'),
      ),
    ];

    if (_isHost) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: _toggleActive,
          icon: Icon(
            customer.isActive ? Icons.block : Icons.check_circle_outline,
          ),
          label: Text(customer.isActive ? 'Nonaktifkan' : 'Aktifkan'),
        ),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }
}
