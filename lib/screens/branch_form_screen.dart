import 'package:flutter/material.dart';

import '../models/managed_branch.dart';
import '../services/api_exception.dart';
import '../services/branch_service.dart';
import '../theme/app_colors.dart';

/// `branchCode` is immutable once created (Kelola doc §1.2, §1.4) — an
/// editable field in create mode only, shown read-only in edit mode.
class BranchFormScreen extends StatefulWidget {
  const BranchFormScreen({
    super.key,
    required this.branchService,
    this.existingBranch,
  });

  final BranchService branchService;
  final ManagedBranch? existingBranch;

  bool get isEditing => existingBranch != null;

  @override
  State<BranchFormScreen> createState() => _BranchFormScreenState();
}

class _BranchFormScreenState extends State<BranchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _branchCodeController = TextEditingController(
    text: widget.existingBranch?.branchCode ?? '',
  );
  late final _nameController = TextEditingController(
    text: widget.existingBranch?.name ?? '',
  );
  late final _addressController = TextEditingController(
    text: widget.existingBranch?.address ?? '',
  );
  late final _phoneController = TextEditingController(
    text: widget.existingBranch?.phone ?? '',
  );
  late final _timezoneController = TextEditingController(
    text: widget.existingBranch?.timezone ?? 'Asia/Jakarta',
  );

  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _branchCodeController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _timezoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final address = _addressController.text.trim().isEmpty
        ? null
        : _addressController.text.trim();
    final phone = _phoneController.text.trim().isEmpty
        ? null
        : _phoneController.text.trim();
    final timezone = _timezoneController.text.trim();

    try {
      final ManagedBranch branch;
      if (widget.isEditing) {
        branch = await widget.branchService.update(
          widget.existingBranch!.id,
          name: name,
          address: address,
          phone: phone,
          timezone: timezone,
        );
      } else {
        branch = await widget.branchService.create(
          branchCode: _branchCodeController.text.trim(),
          name: name,
          address: address,
          phone: phone,
          timezone: timezone,
        );
      }
      if (mounted) Navigator.of(context).pop(branch);
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
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Cabang' : 'Cabang Baru'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _branchCodeController,
                enabled: !widget.isEditing,
                decoration: const InputDecoration(labelText: 'Kode Cabang'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Kode cabang wajib diisi'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama Cabang'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Nama wajib diisi'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Alamat (opsional)',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telepon (opsional)',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _timezoneController,
                decoration: const InputDecoration(
                  labelText: 'Zona Waktu (IANA)',
                  helperText: 'mis. Asia/Jakarta, Asia/Makassar, Asia/Jayapura',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Zona waktu wajib diisi'
                    : null,
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
                    : Text(widget.isEditing ? 'Simpan' : 'Buat Cabang'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
