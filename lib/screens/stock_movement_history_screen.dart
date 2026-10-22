import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/inventory.dart';
import '../models/pagination.dart';
import '../services/api_exception.dart';
import '../services/inventory_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/message_view.dart';
import '../widgets/status_badge.dart';

enum _LoadState { loading, loaded, locked, error }

class StockMovementHistoryScreen extends StatefulWidget {
  const StockMovementHistoryScreen({
    super.key,
    required this.inventoryService,
    required this.itemId,
  });

  final InventoryService inventoryService;
  final String itemId;

  @override
  State<StockMovementHistoryScreen> createState() =>
      _StockMovementHistoryScreenState();
}

class _StockMovementHistoryScreenState
    extends State<StockMovementHistoryScreen> {
  int _page = 1;
  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  List<StockMovement> _movements = const [];
  Pagination? _pagination;

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
      final result = await widget.inventoryService.listStockMovements(
        widget.itemId,
        page: _page,
      );
      setState(() {
        _movements = result.movements;
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

  Color _typeColor(StockMovementType type) => switch (type) {
    StockMovementType.stockIn => AppColors.success,
    StockMovementType.stockOut => AppColors.warning,
    StockMovementType.adjustment => AppColors.info,
  };

  // `movement.quantity` is always a positive magnitude regardless of
  // direction (inventory doc §7) — derive the sign from previous vs
  // new quantity instead of trusting movementType alone, so an
  // ADJUSTMENT that happens to lower stock still shows a minus sign.
  String _signedDelta(StockMovement movement) {
    final delta = movement.newQuantity - movement.previousQuantity;
    final sign = delta > 0 ? '+' : (delta < 0 ? '-' : '');
    return '$sign${movement.quantity}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Pergerakan Stok')),
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
          title: 'Gagal memuat riwayat',
          message: _errorMessage ?? 'Terjadi kesalahan.',
          onRetry: _load,
        );
      case _LoadState.loaded:
        if (_movements.isEmpty) {
          return const Center(child: Text('Belum ada pergerakan stok.'));
        }
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _movements.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _buildRow(context, _movements[index]),
          ),
        );
    }
  }

  Widget _buildRow(BuildContext context, StockMovement movement) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StatusBadge(
                label: movement.movementType.label,
                color: _typeColor(movement.movementType),
              ),
              Text(
                formatDateTime(movement.createdAt),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.secondaryText),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${movement.previousQuantity} → ${movement.newQuantity} '
            '(${_signedDelta(movement)})',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(movement.reason),
          const SizedBox(height: 4),
          Text(
            'Oleh ${movement.performedBy.displayName}',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.secondaryText),
          ),
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
