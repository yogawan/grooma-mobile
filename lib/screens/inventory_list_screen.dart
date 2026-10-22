import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/inventory.dart';
import '../models/pagination.dart';
import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/inventory_service.dart';
import '../theme/app_colors.dart';
import '../widgets/message_view.dart';
import '../widgets/status_badge.dart';
import 'inventory_detail_screen.dart';
import 'inventory_form_screen.dart';

enum _LoadState { loading, loaded, locked, error }

/// Shared list for both roles — AGENT automatically sees only their
/// own branch (inventory doc §1); HOST's `branchId` filter is deferred
/// here the same way it has been for dashboard/transactions.
///
/// Soft-deleted items are **not** hidden by the backend by default
/// (doc §1 warning), so every row always shows an isActive indicator
/// rather than silently filtering them out.
class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({
    super.key,
    required this.inventoryService,
    required this.user,
  });

  final InventoryService inventoryService;
  final User user;

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  final _searchController = TextEditingController();
  bool _lowStockOnly = false;
  int _page = 1;
  Timer? _searchDebounce;

  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  List<InventoryItem> _items = const [];
  Pagination? _pagination;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _state = _LoadState.loading;
      _errorMessage = null;
    });
    try {
      final result = await widget.inventoryService.list(
        page: _page,
        search: _searchController.text.trim(),
        lowStockOnly: _lowStockOnly ? true : null,
      );
      setState(() {
        _items = result.items;
        _pagination = result.pagination;
        _state = _LoadState.loaded;
      });
    } on ApiException catch (e) {
      // ENFORCED for both roles here (inventory doc §0) — AGENT can
      // lock too, unlike TransactionService's list/detail.
      setState(() {
        _state = e.code == 'PAYMENT_REQUIRED'
            ? _LoadState.locked
            : _LoadState.error;
        _errorMessage = e.message;
      });
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _page = 1;
      _load();
    });
  }

  void _toggleLowStock(bool value) {
    setState(() => _lowStockOnly = value);
    _page = 1;
    _load();
  }

  void _changePage(int delta) {
    setState(() => _page += delta);
    _load();
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<InventoryItem>(
      MaterialPageRoute(
        builder: (_) => InventoryFormScreen(
          inventoryService: widget.inventoryService,
          user: widget.user,
        ),
      ),
    );
    if (created != null) _load();
  }

  Future<void> _openDetail(String itemId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InventoryDetailScreen(
          inventoryService: widget.inventoryService,
          user: widget.user,
          itemId: itemId,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventaris')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        child: const Icon(LucideIcons.plus),
      ),
      body: Column(
        children: [
          _buildFilters(context),
          Expanded(child: _buildBody(context)),
          if (_pagination != null) _buildPager(context, _pagination!),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Cari nama item',
              prefixIcon: Icon(LucideIcons.search),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _lowStockOnly,
                onChanged: (v) => _toggleLowStock(v ?? false),
              ),
              const Text('Stok menipis saja'),
            ],
          ),
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
          icon: LucideIcons.lock,
          iconColor: AppColors.warning,
          title: 'Inventaris terkunci',
          message: _errorMessage ?? 'Subscription tidak aktif. Hubungi pemilik untuk memperbarui langganan.',
          onRetry: _load,
        );
      case _LoadState.error:
        return MessageView(
          icon: LucideIcons.circleAlert,
          iconColor: AppColors.error,
          title: 'Gagal memuat inventaris',
          message: _errorMessage ?? 'Terjadi kesalahan.',
          onRetry: _load,
        );
      case _LoadState.loaded:
        if (_items.isEmpty) {
          return const Center(child: Text('Belum ada item.'));
        }
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView.separated(
            itemCount: _items.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, thickness: 1, color: AppColors.border),
            itemBuilder: (context, index) => _buildRow(context, _items[index]),
          ),
        );
    }
  }

  Widget _buildRow(BuildContext context, InventoryItem item) {
    final isHost = widget.user.role == UserRole.host;
    final subtitleParts = [item.itemCode, if (isHost) item.branch.displayName];

    return ListTile(
      onTap: () => _openDetail(item.id),
      title: Row(
        children: [
          Expanded(child: Text(item.name)),
          if (!item.isActive) ...[
            const SizedBox(width: 8),
            const StatusBadge(
              label: 'Nonaktif',
              color: AppColors.secondaryText,
            ),
          ],
        ],
      ),
      subtitle: Text(subtitleParts.join(' • ')),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${item.quantity} ${item.unit}',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          if (item.isLowStock)
            const StatusBadge(label: 'Stok Menipis', color: AppColors.warning),
        ],
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
            onPressed: pagination.page < pagination.totalPages
                ? () => _changePage(1)
                : null,
            child: const Text('Berikutnya'),
          ),
        ],
      ),
    );
  }
}
