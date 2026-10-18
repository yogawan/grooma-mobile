import 'package:flutter/material.dart';

import '../models/managed_branch.dart';
import '../models/profile.dart';
import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/branch_service.dart';
import '../services/staff_service.dart';
import '../theme/app_colors.dart';

/// `username`/`password` only make sense at creation (Kelola doc
/// §2.2/§2.4 — the backend doesn't accept either on PATCH), so this
/// splits those two fields out by [isEditing] same as the other forms
/// in this app. The important part is the role↔branch coupling: AGENT
/// requires a branch, HOST must have none at all — enforced
/// server-side as a 400 either way, mirrored here client-side so the
/// user gets immediate feedback instead of a confusing validation error.
class StaffFormScreen extends StatefulWidget {
  const StaffFormScreen({
    super.key,
    required this.staffService,
    required this.branchService,
    this.existingStaff,
  });

  final StaffService staffService;
  final BranchService branchService;
  final UserProfile? existingStaff;

  bool get isEditing => existingStaff != null;

  @override
  State<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends State<StaffFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _usernameController = TextEditingController(
    text: widget.existingStaff?.username ?? '',
  );
  final _passwordController = TextEditingController();
  late final _nameController = TextEditingController(
    text: widget.existingStaff?.name ?? '',
  );
  late final _phoneController = TextEditingController(
    text: widget.existingStaff?.phone ?? '',
  );

  late UserRole _role = widget.existingStaff?.role ?? UserRole.agent;
  late String? _selectedBranchId = widget.existingStaff?.branch?.id;

  List<ManagedBranch>? _branches;
  String? _branchLoadError;

  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final branches = await widget.branchService.list();
      if (mounted) setState(() => _branches = branches);
    } on ApiException catch (e) {
      if (mounted) setState(() => _branchLoadError = e.message);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
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
    final branchId = _role == UserRole.agent ? _selectedBranchId : null;

    try {
      final UserProfile staff;
      if (widget.isEditing) {
        staff = await widget.staffService.update(
          widget.existingStaff!.id,
          name: name,
          role: _role,
          branchId: branchId,
          phone: phone,
        );
      } else {
        staff = await widget.staffService.create(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          name: name,
          role: _role,
          branchId: branchId,
          phone: phone,
        );
      }
      if (mounted) Navigator.of(context).pop(staff);
    } on ApiException catch (e) {
      setState(() {
        _submitting = false;
        _errorMessage = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAgent = _role == UserRole.agent;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Karyawan' : 'Karyawan Baru'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.isEditing) ...[
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Username wajib diisi'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (value) {
                    final v = value ?? '';
                    if (v.length < 8) return 'Minimal 8 karakter';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Nama wajib diisi'
                    : null,
              ),
              const SizedBox(height: 16),
              Text('Role', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<UserRole>(
                segments: const [
                  ButtonSegment(value: UserRole.agent, label: Text('Agent')),
                  ButtonSegment(value: UserRole.host, label: Text('Host')),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              if (isAgent) ...[
                const SizedBox(height: 16),
                _buildBranchPicker(context),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telepon (opsional)',
                ),
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
                    : Text(widget.isEditing ? 'Simpan' : 'Buat Akun'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBranchPicker(BuildContext context) {
    if (_branchLoadError != null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              'Gagal memuat daftar cabang: $_branchLoadError',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
          TextButton(onPressed: _loadBranches, child: const Text('Coba lagi')),
        ],
      );
    }
    if (_branches == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: _selectedBranchId,
      decoration: const InputDecoration(labelText: 'Cabang'),
      items: _branches!
          .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
          .toList(),
      onChanged: (value) => setState(() => _selectedBranchId = value),
      validator: (value) =>
          value == null ? 'Agent wajib memiliki cabang' : null,
    );
  }
}
