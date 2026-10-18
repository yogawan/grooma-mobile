import 'package:flutter/material.dart';

import '../models/managed_branch.dart';
import '../services/api_exception.dart';
import '../services/branch_service.dart';
import '../theme/app_colors.dart';
import '../widgets/message_view.dart';
import '../widgets/status_badge.dart';
import 'branch_detail_screen.dart';
import 'branch_form_screen.dart';

enum _LoadState { loading, loaded, locked, error }

/// No pagination/search on this endpoint at all (Kelola doc §0, §1.1)
/// — fine at the dozens-of-branches scale this is meant for; a plain
/// full list, no client-side search added for this first pass.
class BranchListScreen extends StatefulWidget {
  const BranchListScreen({super.key, required this.branchService});

  final BranchService branchService;

  @override
  State<BranchListScreen> createState() => _BranchListScreenState();
}

class _BranchListScreenState extends State<BranchListScreen> {
  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  List<ManagedBranch> _branches = const [];

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
      final branches = await widget.branchService.list();
      setState(() {
        _branches = branches;
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

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<ManagedBranch>(
      MaterialPageRoute(
        builder: (_) => BranchFormScreen(branchService: widget.branchService),
      ),
    );
    if (created != null) _load();
  }

  Future<void> _openDetail(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BranchDetailScreen(
          branchService: widget.branchService,
          branchId: id,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cabang')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadState.locked:
        return MessageView(
          icon: Icons.lock_outline,
          iconColor: AppColors.warning,
          title: 'Terkunci',
          message: _errorMessage ?? 'Subscription tidak aktif. Hubungi pemilik untuk memperbarui langganan.',
          onRetry: _load,
        );
      case _LoadState.error:
        return MessageView(
          icon: Icons.error_outline,
          iconColor: AppColors.error,
          title: 'Gagal memuat cabang',
          message: _errorMessage ?? 'Terjadi kesalahan.',
          onRetry: _load,
        );
      case _LoadState.loaded:
        if (_branches.isEmpty) {
          return const Center(child: Text('Belum ada cabang.'));
        }
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView.separated(
            itemCount: _branches.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _buildRow(context, _branches[index]),
          ),
        );
    }
  }

  Widget _buildRow(BuildContext context, ManagedBranch branch) {
    return ListTile(
      onTap: () => _openDetail(branch.id),
      title: Text(branch.name),
      subtitle: Text(branch.branchCode),
      trailing: StatusBadge(
        label: branch.status.label,
        color: branch.status == BranchStatus.active
            ? AppColors.success
            : AppColors.secondaryText,
      ),
    );
  }
}
