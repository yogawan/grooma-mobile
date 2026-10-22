import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/service_item.dart';
import '../services/api_exception.dart';
import '../services/service_catalog_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/message_view.dart';
import '../widgets/status_badge.dart';
import 'service_form_screen.dart';

enum _LoadState { loading, loaded, locked, error }

class ServiceDetailScreen extends StatefulWidget {
  const ServiceDetailScreen({
    super.key,
    required this.serviceCatalogService,
    required this.serviceId,
  });

  final ServiceCatalogService serviceCatalogService;
  final String serviceId;

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  ServiceItem? _service;
  bool _actionInProgress = false;

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
      final service = await widget.serviceCatalogService.detail(
        widget.serviceId,
      );
      setState(() {
        _service = service;
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

  Future<void> _openEdit() async {
    final updated = await Navigator.of(context).push<ServiceItem>(
      MaterialPageRoute(
        builder: (_) => ServiceFormScreen(
          serviceCatalogService: widget.serviceCatalogService,
          existingService: _service,
        ),
      ),
    );
    if (updated != null) setState(() => _service = updated);
  }

  Future<void> _toggleActive() async {
    final service = _service!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          service.isActive ? 'Nonaktifkan layanan?' : 'Aktifkan layanan?',
        ),
        content: Text(
          service.isActive
              ? 'Layanan akan hilang dari pilihan AGENT saat membuat transaksi baru.'
              : 'Layanan akan muncul lagi di pilihan AGENT.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(service.isActive ? 'Nonaktifkan' : 'Aktifkan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _actionInProgress = true);
    try {
      final updated = await widget.serviceCatalogService.setActive(
        service.id,
        !service.isActive,
      );
      setState(() {
        _service = updated;
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
      appBar: AppBar(title: const Text('Detail Layanan')),
      body: _buildBody(context),
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
          title: 'Gagal memuat layanan',
          message: _errorMessage ?? 'Terjadi kesalahan.',
          onRetry: _load,
        );
      case _LoadState.loaded:
        return _buildLoaded(context, _service!);
    }
  }

  Widget _buildLoaded(BuildContext context, ServiceItem service) {
    return AbsorbPointer(
      absorbing: _actionInProgress,
      child: Opacity(
        opacity: _actionInProgress ? 0.6 : 1,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      service.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (!service.isActive)
                    const StatusBadge(
                      label: 'Nonaktif',
                      color: AppColors.secondaryText,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row(context, 'Kode Layanan', service.serviceCode),
                    _row(context, 'Kategori', service.category ?? '-'),
                    _row(context, 'Harga', formatRupiah(service.price)),
                    _row(context, 'Durasi', '${service.durationMinutes} menit'),
                    _row(
                      context,
                      'Bagi Hasil',
                      'Owner ${service.revenueSharing.ownerPercentage}% · '
                          'Karyawan ${service.revenueSharing.employeePercentage}%',
                    ),
                    if (service.description != null &&
                        service.description!.isNotEmpty)
                      _row(context, 'Deskripsi', service.description!),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mengubah harga tidak memengaruhi transaksi lama — setiap '
                'transaksi menyimpan harga saat itu dibuat.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.secondaryText),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _openEdit,
                    icon: const Icon(LucideIcons.pencil),
                    label: const Text('Edit'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _toggleActive,
                    icon: Icon(
                      service.isActive
                          ? LucideIcons.ban
                          : LucideIcons.circleCheck,
                    ),
                    label: Text(service.isActive ? 'Nonaktifkan' : 'Aktifkan'),
                  ),
                ],
              ),
            ],
          ),
        ),
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
}
