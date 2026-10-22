import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/profile.dart';
import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/branch_service.dart';
import '../services/staff_service.dart';
import '../theme/app_colors.dart';
import '../widgets/message_view.dart';
import '../widgets/status_badge.dart';
import 'staff_form_screen.dart';

enum _LoadState { loading, loaded, locked, error }

/// No "reset password" action here on purpose — the backend has no
/// such endpoint (Kelola doc §2.4). The only recovery path for a
/// locked-out AGENT today is deactivate + recreate.
class StaffDetailScreen extends StatefulWidget {
  const StaffDetailScreen({
    super.key,
    required this.staffService,
    required this.branchService,
    required this.staffId,
  });

  final StaffService staffService;
  final BranchService branchService;
  final String staffId;

  @override
  State<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends State<StaffDetailScreen> {
  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  UserProfile? _staff;
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
      final staff = await widget.staffService.detail(widget.staffId);
      setState(() {
        _staff = staff;
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
    final updated = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(
        builder: (_) => StaffFormScreen(
          staffService: widget.staffService,
          branchService: widget.branchService,
          existingStaff: _staff,
        ),
      ),
    );
    if (updated != null) setState(() => _staff = updated);
  }

  Future<void> _toggleStatus() async {
    final staff = _staff!;
    final nextStatus = staff.status == UserStatus.active
        ? UserStatus.inactive
        : UserStatus.active;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          nextStatus == UserStatus.inactive
              ? 'Nonaktifkan akun?'
              : 'Aktifkan akun?',
        ),
        content: Text(
          nextStatus == UserStatus.inactive
              ? 'Akun tidak akan bisa login, dan sesi yang sedang aktif langsung berhenti berfungsi.'
              : 'Akun akan bisa login kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              nextStatus == UserStatus.inactive ? 'Nonaktifkan' : 'Aktifkan',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _actionInProgress = true);
    try {
      final updated = await widget.staffService.setStatus(staff.id, nextStatus);
      setState(() {
        _staff = updated;
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
      appBar: AppBar(title: const Text('Detail Karyawan')),
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
          title: 'Gagal memuat karyawan',
          message: _errorMessage ?? 'Terjadi kesalahan.',
          onRetry: _load,
        );
      case _LoadState.loaded:
        return _buildLoaded(context, _staff!);
    }
  }

  Widget _buildLoaded(BuildContext context, UserProfile staff) {
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
                      staff.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  StatusBadge(
                    label: staff.status == UserStatus.active
                        ? 'Aktif'
                        : 'Nonaktif',
                    color: staff.status == UserStatus.active
                        ? AppColors.success
                        : AppColors.secondaryText,
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
                    _row(context, 'Username', staff.username),
                    _row(
                      context,
                      'Role',
                      staff.role == UserRole.host ? 'Host' : 'Agent',
                    ),
                    if (staff.branch != null)
                      _row(context, 'Cabang', staff.branch!.name),
                    _row(context, 'Telepon', staff.phone ?? '-'),
                  ],
                ),
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
                    onPressed: _toggleStatus,
                    icon: Icon(
                      staff.status == UserStatus.active
                          ? LucideIcons.ban
                          : LucideIcons.circleCheck,
                    ),
                    label: Text(
                      staff.status == UserStatus.active
                          ? 'Nonaktifkan'
                          : 'Aktifkan',
                    ),
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
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
