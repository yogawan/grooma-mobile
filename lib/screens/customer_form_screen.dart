import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../services/api_exception.dart';
import '../services/customer_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';

/// Create and edit share one form. Privileged fields (email/gender/
/// birthDate/address/notes) are hidden from the form entirely when
/// [isHost] is false — not because the backend rejects AGENT writes to
/// them (it doesn't, customer doc §5), but so AGENT can't blind-write
/// data it can never read back.
class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({
    super.key,
    required this.customerService,
    required this.isHost,
    this.existingCustomer,
  });

  final CustomerService customerService;
  final bool isHost;
  final Customer? existingCustomer;

  bool get isEditing => existingCustomer != null;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existingCustomer?.name ?? '',
  );
  late final _phoneController = TextEditingController(
    text: widget.existingCustomer?.phone ?? '',
  );
  late final _emailController = TextEditingController(
    text: widget.existingCustomer?.email ?? '',
  );
  late final _addressController = TextEditingController(
    text: widget.existingCustomer?.address ?? '',
  );
  late final _notesController = TextEditingController(
    text: widget.existingCustomer?.notes ?? '',
  );

  late CustomerGender? _gender = widget.existingCustomer?.gender;
  late DateTime? _birthDate = widget.existingCustomer?.birthDate;

  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim().isEmpty
        ? null
        : _phoneController.text.trim();
    final email = !widget.isHost || _emailController.text.trim().isEmpty
        ? null
        : _emailController.text.trim();
    final address = !widget.isHost || _addressController.text.trim().isEmpty
        ? null
        : _addressController.text.trim();
    final notes = !widget.isHost || _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();
    final gender = widget.isHost ? _gender : null;
    final birthDate = widget.isHost ? _birthDate : null;

    try {
      final Customer customer;
      if (widget.isEditing) {
        customer = await widget.customerService.update(
          widget.existingCustomer!.id,
          name: name,
          phone: phone,
          email: email,
          gender: gender,
          birthDate: birthDate,
          address: address,
          notes: notes,
        );
      } else {
        customer = await widget.customerService.create(
          name: name,
          phone: phone,
          email: email,
          gender: gender,
          birthDate: birthDate,
          address: address,
          notes: notes,
        );
      }

      if (!mounted) return;

      // customer doc §3: a 201 on create doesn't always mean a new
      // record — a phone match returns the existing customer instead.
      // A `createdAt` far in the past is the most reliable signal of
      // that (comparing names can coincidentally match/mismatch).
      final isExistingMatch =
          !widget.isEditing &&
          DateTime.now().difference(customer.createdAt).inSeconds > 10;
      if (isExistingMatch) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Customer sudah terdaftar'),
            content: Text(
              'Nomor HP ini sudah terdaftar atas nama "${customer.name}". '
              'Data yang sudah ada akan dipakai.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Mengerti'),
              ),
            ],
          ),
        );
      }

      if (mounted) Navigator.of(context).pop(customer);
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
        title: Text(widget.isEditing ? 'Edit Customer' : 'Customer Baru'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Nama wajib diisi'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor HP (opsional)',
                ),
              ),
              if (widget.isHost) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email (opsional)',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<CustomerGender?>(
                  initialValue: _gender,
                  decoration: const InputDecoration(
                    labelText: 'Jenis Kelamin (opsional)',
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('-')),
                    ...CustomerGender.values.map(
                      (g) => DropdownMenuItem(value: g, child: Text(g.label)),
                    ),
                  ],
                  onChanged: (value) => setState(() => _gender = value),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickBirthDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tanggal Lahir (opsional)',
                    ),
                    child: Text(
                      _birthDate == null
                          ? 'Pilih tanggal'
                          : formatDate(_birthDate!),
                    ),
                  ),
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
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (opsional)',
                  ),
                ),
              ],
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
                    : Text(widget.isEditing ? 'Simpan' : 'Buat Customer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
