import 'package:flutter/material.dart';

import '../models/service_item.dart';
import '../services/api_exception.dart';
import '../services/service_catalog_service.dart';
import '../theme/app_colors.dart';

/// `serviceCode` is immutable once created (Kelola doc §3.3, §3.4) —
/// editable in create mode only, same pattern as Branch's
/// `branchCode`. Revenue share is a single slider (owner's cut) that
/// derives the employee's share, so the two can never fail to sum to
/// 100 the way two free-standing inputs could (doc's explicit warning).
class ServiceFormScreen extends StatefulWidget {
  const ServiceFormScreen({
    super.key,
    required this.serviceCatalogService,
    this.existingService,
  });

  final ServiceCatalogService serviceCatalogService;
  final ServiceItem? existingService;

  bool get isEditing => existingService != null;

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _serviceCodeController = TextEditingController(
    text: widget.existingService?.serviceCode ?? '',
  );
  late final _nameController = TextEditingController(
    text: widget.existingService?.name ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.existingService?.description ?? '',
  );
  late final _categoryController = TextEditingController(
    text: widget.existingService?.category ?? '',
  );
  late final _priceController = TextEditingController(
    text: '${widget.existingService?.price ?? 0}',
  );
  late final _durationController = TextEditingController(
    text: '${widget.existingService?.durationMinutes ?? 30}',
  );

  late double _ownerPercentage =
      (widget.existingService?.revenueSharing.ownerPercentage ?? 70).toDouble();

  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _serviceCodeController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();
    final category = _categoryController.text.trim().isEmpty
        ? null
        : _categoryController.text.trim();
    final price = num.tryParse(_priceController.text.trim()) ?? 0;
    final duration = int.tryParse(_durationController.text.trim()) ?? 30;
    final revenueSharing = RevenueSharing(
      ownerPercentage: _ownerPercentage.round(),
      employeePercentage: 100 - _ownerPercentage.round(),
    );

    try {
      final ServiceItem service;
      if (widget.isEditing) {
        service = await widget.serviceCatalogService.update(
          widget.existingService!.id,
          name: name,
          description: description,
          category: category,
          price: price,
          durationMinutes: duration,
          revenueSharing: revenueSharing,
        );
      } else {
        service = await widget.serviceCatalogService.create(
          serviceCode: _serviceCodeController.text.trim(),
          name: name,
          description: description,
          category: category,
          price: price,
          durationMinutes: duration,
          revenueSharing: revenueSharing,
        );
      }
      if (mounted) Navigator.of(context).pop(service);
    } on ApiException catch (e) {
      setState(() {
        _submitting = false;
        _errorMessage = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ownerShare = _ownerPercentage.round();
    final employeeShare = 100 - ownerShare;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Layanan' : 'Layanan Baru'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _serviceCodeController,
                enabled: !widget.isEditing,
                decoration: const InputDecoration(labelText: 'Kode Layanan'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Kode layanan wajib diisi'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama Layanan'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Nama wajib diisi'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Kategori (opsional, bebas)',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi (opsional)',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: false,
                ),
                decoration: const InputDecoration(labelText: 'Harga (Rp)'),
                validator: (value) {
                  final parsed = num.tryParse(value?.trim() ?? '');
                  if (parsed == null || parsed < 0) return 'Harga tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Durasi (menit)'),
                validator: (value) {
                  final parsed = int.tryParse(value?.trim() ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Durasi harus lebih dari 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text('Bagi Hasil', style: Theme.of(context).textTheme.labelLarge),
              Text(
                'Owner $ownerShare% · Karyawan $employeeShare%',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.secondaryText),
              ),
              Slider(
                value: _ownerPercentage,
                min: 0,
                max: 100,
                divisions: 100,
                label: '$ownerShare%',
                onChanged: (value) => setState(() => _ownerPercentage = value),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
              const SizedBox(height: 16),
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
                    : Text(widget.isEditing ? 'Simpan' : 'Buat Layanan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
