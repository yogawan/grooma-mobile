import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/auth_controller.dart';
import '../services/profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/message_view.dart';

enum _LoadState { loading, loaded, error }

/// `username`/`role`/`branch`/`status` are immutable through this
/// endpoint (profile doc §6) — shown read-only, never as editable
/// fields. Only `name`/`phone` get a form. Change-password is a
/// separate endpoint, out of scope here (profile doc §4.2).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.profileService,
    required this.authController,
  });

  final ProfileService profileService;
  final AuthController authController;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  UserProfile? _profile;

  bool _editing = false;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _state = _LoadState.loading;
      _errorMessage = null;
    });
    try {
      final profile = await widget.profileService.getProfile();
      _nameController.text = profile.name;
      _phoneController.text = profile.phone ?? '';
      setState(() {
        _profile = profile;
        _state = _LoadState.loaded;
      });
    } on ApiException catch (e) {
      setState(() {
        _state = _LoadState.error;
        _errorMessage = e.message;
      });
    }
  }

  void _startEditing() {
    setState(() {
      _saveError = null;
      _editing = true;
    });
  }

  void _cancelEditing() {
    final profile = _profile!;
    _nameController.text = profile.name;
    _phoneController.text = profile.phone ?? '';
    setState(() {
      _saveError = null;
      _editing = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final updated = await widget.profileService.updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      widget.authController.updateName(updated.name);
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _saving = false;
        _editing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui')),
      );
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _saveError = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          if (_state == _LoadState.loaded && !_editing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Profil',
              onPressed: _startEditing,
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: widget.authController.logout,
          ),
        ],
      ),
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
          title: 'Gagal memuat profil',
          message: _errorMessage ?? 'Terjadi kesalahan.',
          onRetry: _load,
        );
      case _LoadState.loaded:
        return _editing
            ? _buildEditForm(context, _profile!)
            : _buildReadOnlyView(context, _profile!);
    }
  }

  /// Default view — everything read-only, nothing pre-armed for
  /// editing. Matches the "view first, edit on request" pattern instead
  /// of landing straight on a live form: most visits here are just to
  /// check your own info, not to change it.
  Widget _buildReadOnlyView(BuildContext context, UserProfile profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _infoCard(context, profile, showEditableFields: true),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _startEditing,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit Profil'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm(BuildContext context, UserProfile profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _infoCard(context, profile, showEditableFields: false),
            const SizedBox(height: 24),
            Text('Edit Profil', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nama'),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) return 'Nama wajib diisi';
                if (trimmed.length > 100) return 'Nama maksimal 100 karakter';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nomor Telepon'),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.length > 32) {
                  return 'Nomor telepon maksimal 32 karakter';
                }
                return null;
              },
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 12),
              Text(_saveError!, style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _cancelEditing,
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : const Text('Simpan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// `showEditableFields` adds Nama/No. Telepon as read-only rows for
  /// the view-mode card — in edit mode those two live in the form
  /// instead, so this card sticks to the fields that are never editable
  /// through this endpoint (profile doc §6).
  Widget _infoCard(
    BuildContext context,
    UserProfile profile, {
    required bool showEditableFields,
  }) {
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
          if (showEditableFields) ...[
            _infoRow(context, 'Nama', profile.name),
            _infoRow(
              context,
              'No. Telepon',
              (profile.phone?.isNotEmpty ?? false) ? profile.phone! : '-',
            ),
          ],
          _infoRow(context, 'Username', profile.username),
          _infoRow(
            context,
            'Role',
            profile.role == UserRole.host ? 'Host' : 'Agent',
          ),
          if (profile.branch != null)
            _infoRow(context, 'Cabang', profile.branch!.name),
          _infoRow(
            context,
            'Status',
            profile.status == UserStatus.active ? 'Aktif' : 'Nonaktif',
            valueColor: profile.status == UserStatus.active
                ? AppColors.success
                : AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.secondaryText),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: valueColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
