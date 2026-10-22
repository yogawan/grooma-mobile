import 'package:flutter/material.dart';

import '../models/pagination.dart';
import '../models/profile.dart';
import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/branch_service.dart';
import '../services/staff_service.dart';
import '../theme/app_colors.dart';
import '../widgets/message_view.dart';
import '../widgets/status_badge.dart';
import 'staff_detail_screen.dart';
import 'staff_form_screen.dart';

enum _LoadState { loading, loaded, locked, error }

/// Paginated now (AUTH doc §2.1.4) — default 20 rows per page, no
/// search/filter added for this first pass.
class StaffListScreen extends StatefulWidget {
  const StaffListScreen({
    super.key,
    required this.staffService,
    required this.branchService,
  });

  final StaffService staffService;
  final BranchService branchService;

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  List<UserProfile> _staff = const [];
  Pagination? _pagination;
  int _page = 1;

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
      final result = await widget.staffService.list(page: _page);
      setState(() {
        _staff = result.users;
        _pagination = result.pagination;
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

  void _changePage(int delta) {
    setState(() => _page += delta);
    _load();
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(
        builder: (_) => StaffFormScreen(
          staffService: widget.staffService,
          branchService: widget.branchService,
        ),
      ),
    );
    if (created != null) _load();
  }

  Future<void> _openDetail(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StaffDetailScreen(
          staffService: widget.staffService,
          branchService: widget.branchService,
          staffId: id,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Karyawan')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody(context)),
          if (_pagination != null) _buildPager(context, _pagination!),
        ],
      ),
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
          title: 'Gagal memuat karyawan',
          message: _errorMessage ?? 'Terjadi kesalahan.',
          onRetry: _load,
        );
      case _LoadState.loaded:
        if (_staff.isEmpty) {
          return const Center(child: Text('Belum ada karyawan.'));
        }
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView.separated(
            itemCount: _staff.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, thickness: 1, color: AppColors.border),
            itemBuilder: (context, index) => _buildRow(context, _staff[index]),
          ),
        );
    }
  }

  Widget _buildRow(BuildContext context, UserProfile staff) {
    final subtitleParts = [
      staff.role == UserRole.host ? 'Host' : 'Agent',
      if (staff.branch != null) staff.branch!.name,
    ];
    return ListTile(
      onTap: () => _openDetail(staff.id),
      title: Text(staff.name),
      subtitle: Text(subtitleParts.join(' • ')),
      trailing: StatusBadge(
        label: staff.status == UserStatus.active ? 'Aktif' : 'Nonaktif',
        color: staff.status == UserStatus.active
            ? AppColors.success
            : AppColors.secondaryText,
      ),
    );
  }

  Widget _buildPager(BuildContext context, Pagination pagination) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: pagination.page > 1 ? () => _changePage(-1) : null,
            child: const Text('Sebelumnya'),
          ),
          Text(
            'Halaman ${pagination.page} dari ${pagination.totalPages == 0 ? 1 : pagination.totalPages}',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.secondaryText),
          ),
          TextButton(
            onPressed: pagination.hasNextPage ? () => _changePage(1) : null,
            child: const Text('Berikutnya'),
          ),
        ],
      ),
    );
  }
}
