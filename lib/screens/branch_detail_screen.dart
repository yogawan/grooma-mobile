import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/managed_branch.dart';
import '../services/api_exception.dart';
import '../services/branch_service.dart';
import '../theme/app_colors.dart';
import '../widgets/message_view.dart';
import '../widgets/status_badge.dart';
import 'branch_form_screen.dart';

enum _LoadState { loading, loaded, locked, error }

class BranchDetailScreen extends StatefulWidget {
  const BranchDetailScreen({
    super.key,
    required this.branchService,
    required this.branchId,
  });

  final BranchService branchService;
  final String branchId;

  @override
  State<BranchDetailScreen> createState() => _BranchDetailScreenState();
}

class _BranchDetailScreenState extends State<BranchDetailScreen> {
  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  ManagedBranch? _branch;
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
      final branch = await widget.branchService.detail(widget.branchId);
      setState(() {
        _branch = branch;
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
    final updated = await Navigator.of(context).push<ManagedBranch>(
      MaterialPageRoute(
        builder: (_) => BranchFormScreen(
          branchService: widget.branchService,
          existingBranch: _branch,
        ),
      ),
    );
    if (updated != null) setState(() => _branch = updated);
  }

  Future<void> _toggleStatus() async {
    final branch = _branch!;
    final nextStatus = branch.status == BranchStatus.active
        ? BranchStatus.inactive
        : BranchStatus.active;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          nextStatus == BranchStatus.inactive
              ? 'Nonaktifkan cabang?'
              : 'Aktifkan cabang?',
        ),
        content: Text(
          nextStatus == BranchStatus.inactive
              ? 'AGENT tidak akan bisa membuat transaksi baru di cabang ini selama nonaktif.'
              : 'Cabang akan bisa dipakai lagi untuk transaksi baru.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              nextStatus == BranchStatus.inactive ? 'Nonaktifkan' : 'Aktifkan',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _actionInProgress = true);
    try {
      final updated = await widget.branchService.setStatus(
        branch.id,
        nextStatus,
      );
      setState(() {
        _branch = updated;
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
      appBar: AppBar(title: const Text('Detail Cabang')),
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
          title: 'Gagal memuat cabang',
          message: _errorMessage ?? 'Terjadi kesalahan.',
          onRetry: _load,
        );
      case _LoadState.loaded:
        return _buildLoaded(context, _branch!);
    }
  }

  Widget _buildLoaded(BuildContext context, ManagedBranch branch) {
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
                      branch.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  StatusBadge(
                    label: branch.status.label,
                    color: branch.status == BranchStatus.active
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
                    _row(context, 'Kode Cabang', branch.branchCode),
                    _row(context, 'Alamat', branch.address ?? '-'),
                    _row(context, 'Telepon', branch.phone ?? '-'),
                    _row(context, 'Zona Waktu', branch.timezone),
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
                      branch.status == BranchStatus.active
                          ? LucideIcons.ban
                          : LucideIcons.circleCheck,
                    ),
                    label: Text(
                      branch.status == BranchStatus.active
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
