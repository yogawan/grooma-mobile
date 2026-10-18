import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../services/api_exception.dart';
import '../services/change_request_service.dart';
import '../theme/app_colors.dart';

/// Only 4 fields can be requested here — `serviceId`, `customerId`,
/// `discountAmount`, `serviceHourType` (change-requests doc §2) — and
/// at least one of them must be set. `serviceId`/`customerId` are plain
/// manual-entry fields for the same reason as CreateTransactionScreen:
/// no catalog endpoint exists yet to pick from.
class ChangeRequestFormScreen extends StatefulWidget {
  const ChangeRequestFormScreen({
    super.key,
    required this.changeRequestService,
    required this.transactionId,
  });

  final ChangeRequestService changeRequestService;
  final String transactionId;

  @override
  State<ChangeRequestFormScreen> createState() =>
      _ChangeRequestFormScreenState();
}

class _ChangeRequestFormScreenState extends State<ChangeRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _serviceIdController = TextEditingController();
  final _customerIdController = TextEditingController();
  final _discountController = TextEditingController();

  ServiceHourType? _hourType;
  bool _submitting = false;
  String? _errorMessage;
  String? _noChangesError;

  @override
  void dispose() {
    _reasonController.dispose();
    _serviceIdController.dispose();
    _customerIdController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final serviceId = _serviceIdController.text.trim();
    final customerId = _customerIdController.text.trim();
    final discountText = _discountController.text.trim();
    final hasAnyChange =
        serviceId.isNotEmpty ||
        customerId.isNotEmpty ||
        discountText.isNotEmpty ||
        _hourType != null;

    setState(() {
      _noChangesError = hasAnyChange ? null : 'Isi minimal satu perubahan (service, customer, diskon, atau jenis jam).';
    });
    if (!_formKey.currentState!.validate() || !hasAnyChange) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await widget.changeRequestService.submit(
        widget.transactionId,
        reason: _reasonController.text.trim(),
        serviceId: serviceId.isEmpty ? null : serviceId,
        customerId: customerId.isEmpty ? null : customerId,
        discountAmount: discountText.isEmpty
            ? null
            : num.tryParse(discountText),
        serviceHourType: _hourType,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _submitting = false;
        _errorMessage = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajukan Koreksi')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Alasan'),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return 'Alasan wajib diisi';
                  if (trimmed.length > 1000) return 'Maksimal 1000 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Isi minimal satu perubahan di bawah ini:',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _serviceIdController,
                decoration: const InputDecoration(
                  labelText: 'Service ID baru (opsional)',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _customerIdController,
                decoration: const InputDecoration(
                  labelText: 'Customer ID baru (opsional)',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _discountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: false,
                ),
                decoration: const InputDecoration(
                  labelText: 'Diskon baru (opsional)',
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return null;
                  final parsed = num.tryParse(trimmed);
                  if (parsed == null || parsed < 0) return 'Diskon tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ServiceHourType?>(
                initialValue: _hourType,
                decoration: const InputDecoration(
                  labelText: 'Jenis jam baru (opsional)',
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Tidak diubah')),
                  DropdownMenuItem(
                    value: ServiceHourType.regular,
                    child: Text('Reguler'),
                  ),
                  DropdownMenuItem(
                    value: ServiceHourType.overtime,
                    child: Text('Lembur'),
                  ),
                ],
                onChanged: (value) => setState(() => _hourType = value),
              ),
              if (_noChangesError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _noChangesError!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
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
                    : const Text('Ajukan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
