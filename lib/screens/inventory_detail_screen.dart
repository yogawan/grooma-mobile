import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/inventory.dart';
import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/inventory_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/message_view.dart';
import '../widgets/status_badge.dart';
import 'inventory_form_screen.dart';
import 'stock_movement_form_screen.dart';
import 'stock_movement_history_screen.dart';

enum _LoadState { loading, loaded, locked, error }

class InventoryDetailScreen extends StatefulWidget {
  const InventoryDetailScreen({
    super.key,
    required this.inventoryService,
    required this.user,
    required this.itemId,
  });

  final InventoryService inventoryService;
  final User user;
  final String itemId;

  @override
  State<InventoryDetailScreen> createState() => _InventoryDetailScreenState();
}

class _InventoryDetailScreenState extends State<InventoryDetailScreen> {
  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  InventoryItem? _item;
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
      final item = await widget.inventoryService.detail(widget.itemId);
      setState(() {
        _item = item;
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

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openEdit() async {
    final updated = await Navigator.of(context).push<InventoryItem>(
      MaterialPageRoute(
        builder: (_) => InventoryFormScreen(
          inventoryService: widget.inventoryService,
          user: widget.user,
          existingItem: _item,
        ),
      ),
    );
    if (updated != null) setState(() => _item = updated);
  }

  Future<void> _openRecordMovement() async {
    final updated = await Navigator.of(context).push<InventoryItem>(
      MaterialPageRoute(
        builder: (_) => StockMovementFormScreen(
          inventoryService: widget.inventoryService,
          itemId: widget.itemId,
          currentQuantity: _item!.quantity,
        ),
      ),
    );
    if (updated != null) setState(() => _item = updated);
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StockMovementHistoryScreen(
          inventoryService: widget.inventoryService,
          itemId: widget.itemId,
        ),
      ),
    );
  }

  Future<void> _deactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nonaktifkan item?'),
        content: const Text(
          'Item tidak akan dihapus permanen, tapi tidak bisa lagi menerima '
          'pergerakan stok baru. Riwayat lama tetap tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _actionInProgress = true);
    try {
      final updated = await widget.inventoryService.deactivate(widget.itemId);
      setState(() {
        _item = updated;
        _actionInProgress = false;
      });
      _showMessage('Item dinonaktifkan.');
    } on ApiException catch (e) {
      setState(() => _actionInProgress = false);
      _showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Item')),
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
          title: 'Inventaris terkunci',
          message: _errorMessage ?? 'Subscription tidak aktif. Hubungi pemilik untuk memperbarui langganan.',
          onRetry: _load,
        );
      case _LoadState.error:
        return MessageView(
          icon: LucideIcons.circleAlert,
          iconColor: AppColors.error,
          title: 'Gagal memuat item',
          message: _errorMessage ?? 'Terjadi kesalahan.',
          onRetry: _load,
        );
      case _LoadState.loaded:
        return _buildLoaded(context, _item!);
    }
  }

  Widget _buildLoaded(BuildContext context, InventoryItem item) {
    return AbsorbPointer(
      absorbing: _actionInProgress,
      child: Opacity(
        opacity: _actionInProgress ? 0.6 : 1,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, item),
              const SizedBox(height: 16),
              _buildInfoCard(context, item),
              const SizedBox(height: 16),
              _buildActions(context, item),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, InventoryItem item) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: Theme.of(context).textTheme.titleLarge),
              Text(
                item.itemCode,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!item.isActive)
              const StatusBadge(
                label: 'Nonaktif',
                color: AppColors.secondaryText,
              ),
            if (item.isLowStock) ...[
              const SizedBox(height: 4),
              const StatusBadge(
                label: 'Stok Menipis',
                color: AppColors.warning,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, InventoryItem item) {
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
          _row(context, 'Cabang', item.branch.displayName),
          _row(context, 'Kategori', item.category.label),
          _row(
            context,
            'Stok',
            '${item.quantity} ${item.unit}',
            emphasize: true,
          ),
          _row(context, 'Stok Minimum', '${item.minimumStock} ${item.unit}'),
          _row(context, 'Harga Satuan', formatRupiah(item.unitCost)),
          _row(context, 'Total Nilai', formatRupiah(item.totalValue)),
          if (item.supplier != null && item.supplier!.isNotEmpty)
            _row(context, 'Supplier', item.supplier!),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool emphasize = false,
  }) {
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
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, InventoryItem item) {
    final buttons = <Widget>[
      OutlinedButton.icon(
        onPressed: _openEdit,
        icon: const Icon(LucideIcons.pencil),
        label: const Text('Edit'),
      ),
      OutlinedButton.icon(
        onPressed: _openHistory,
        icon: const Icon(LucideIcons.history),
        label: const Text('Riwayat Stok'),
      ),
    ];

    // Stock movements 422 once an item is inactive (inventory doc §7) —
    // don't offer a button that's guaranteed to fail.
    if (item.isActive) {
      buttons.add(
        FilledButton.icon(
          onPressed: _openRecordMovement,
          icon: const Icon(LucideIcons.arrowUpDown),
          label: const Text('Catat Pergerakan'),
        ),
      );
      buttons.add(
        OutlinedButton.icon(
          onPressed: _deactivate,
          icon: const Icon(LucideIcons.ban),
          label: const Text('Nonaktifkan'),
        ),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }
}
