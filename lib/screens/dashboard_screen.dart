import 'package:flutter/material.dart';

import '../models/dashboard.dart';
import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/dashboard_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/message_view.dart';

enum _LoadState { loading, loaded, locked, error }

/// Shared dashboard body for both HOST and AGENT (dashboard doc §5: same
/// endpoints/shapes for both, scope is resolved server-side from the
/// session). `branchId`/`agentId` HOST filters are deferred — out of
/// scope for this simple first pass.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.dashboardService,
    required this.user,
  });

  final DashboardService dashboardService;
  final User user;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Backend maxes (dashboard doc §3.3/§3.4/§3.6) — "Lihat lebih banyak"
  // jumps straight to these rather than incrementing, since there's no
  // `page` on these endpoints to step through (§0: ranking/worklist
  // depth only, not real pagination).
  static const _maxServicesLimit = 50;
  static const _maxAgentsLimit = 100;
  static const _maxInventoryLimit = 100;

  DashboardPeriod _period = DashboardPeriod.month;
  _LoadState _state = _LoadState.loading;
  String? _errorMessage;

  int _servicesLimit = 10;
  int _agentsLimit = 50;
  int _inventoryLimit = 20;

  DashboardSummary? _summary;
  RevenueData? _revenue;
  ServiceStatsResult? _services;
  AgentStatsResult? _agents;
  TransactionStats? _transactions;
  LowStockResult? _inventory;

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
      // Awaited first, alone: if the HOST subscription is lapsed, every
      // endpoint in this module 402s the same way (dashboard doc §0, §4),
      // so there's no point firing the other five in that case.
      final summary = await widget.dashboardService.summary(period: _period);

      final revenueFuture = widget.dashboardService.revenue(period: _period);
      final servicesFuture = widget.dashboardService.services(
        period: _period,
        limit: _servicesLimit,
      );
      final agentsFuture = widget.dashboardService.agents(
        period: _period,
        limit: _agentsLimit,
      );
      final transactionsFuture = widget.dashboardService.transactionsStats(
        period: _period,
      );
      final inventoryFuture = widget.dashboardService.inventory(
        limit: _inventoryLimit,
      );

      final revenue = await revenueFuture;
      final services = await servicesFuture;
      final agents = await agentsFuture;
      final transactions = await transactionsFuture;
      final inventory = await inventoryFuture;

      setState(() {
        _summary = summary;
        _revenue = revenue;
        _services = services;
        _agents = agents;
        _transactions = transactions;
        _inventory = inventory;
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

  void _showMoreServices() {
    _servicesLimit = _maxServicesLimit;
    _load();
  }

  void _showMoreAgents() {
    _agentsLimit = _maxAgentsLimit;
    _load();
  }

  void _showMoreInventory() {
    _inventoryLimit = _maxInventoryLimit;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadState.locked:
        return MessageView(
          icon: Icons.lock_outline,
          iconColor: AppColors.warning,
          title: 'Dashboard terkunci',
          message: _errorMessage ?? 'Subscription tidak aktif. Hubungi pemilik untuk memperbarui langganan.',
          onRetry: _load,
        );
      case _LoadState.error:
        return MessageView(
          icon: Icons.error_outline,
          iconColor: AppColors.error,
          title: 'Gagal memuat dashboard',
          message: _errorMessage ?? 'Terjadi kesalahan.',
          onRetry: _load,
        );
      case _LoadState.loaded:
        return RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Halo, ${widget.user.name}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  widget.user.role == UserRole.host
                      ? 'Semua cabang'
                      : 'Cabang: ${widget.user.branch?.name ?? '-'}',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColors.secondaryText),
                ),
                const SizedBox(height: 12),
                _buildPeriodSelector(),
                const SizedBox(height: 20),
                _buildSummary(context),
                const SizedBox(height: 24),
                _buildRevenue(context),
                const SizedBox(height: 24),
                _buildServices(context),
                const SizedBox(height: 24),
                _buildAgents(context),
                const SizedBox(height: 24),
                _buildTransactions(context),
                const SizedBox(height: 24),
                _buildInventory(context),
              ],
            ),
          ),
        );
    }
  }

  Widget _buildPeriodSelector() {
    return SegmentedButton<DashboardPeriod>(
      segments: DashboardPeriod.values
          .map((p) => ButtonSegment(value: p, label: Text(p.label)))
          .toList(),
      selected: {_period},
      onSelectionChanged: (selection) {
        setState(() => _period = selection.first);
        _load();
      },
    );
  }

  Widget _buildSummary(BuildContext context) {
    final summary = _summary!;
    final stats = [
      ('Total Revenue', formatRupiah(summary.totalRevenue)),
      ('Jumlah Transaksi', '${summary.transactionCount}'),
      ('Rata-rata Order', formatRupiah(summary.avgOrderValue)),
      ('Customer Unik', '${summary.uniqueCustomers}'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'Ringkasan'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: stats
              .map(
                (s) => SizedBox(
                  width: (MediaQuery.of(context).size.width - 16 * 2 - 12) / 2,
                  child: _statCard(context, s.$1, s.$2),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildRevenue(BuildContext context) {
    final revenue = _revenue!;
    return _card(
      context,
      title: 'Revenue',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (revenue.byPeriod.isEmpty)
            _emptyText('Belum ada data revenue.')
          else
            ...revenue.byPeriod.map(
              (p) => _kvRow(
                context,
                p.label,
                '${formatRupiah(p.revenue)} (${p.transactionCount}x)',
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Metode Pembayaran',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          if (revenue.paymentBreakdown.isEmpty)
            _emptyText('Belum ada data.')
          else
            ...revenue.paymentBreakdown.map(
              (p) => _kvRow(
                context,
                p.method,
                '${formatRupiah(p.revenue)} (${p.count}x)',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildServices(BuildContext context) {
    final result = _services!;
    final services = result.services;
    return _card(
      context,
      title: 'Top Layanan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (services.isEmpty)
            _emptyText('Belum ada data layanan.')
          else
            for (var i = 0; i < services.length; i++)
              _kvRow(
                context,
                '${i + 1}. ${services[i].serviceName}',
                '${formatRupiah(services[i].revenue)} (${services[i].count}x)',
              ),
          if (result.meta.truncated)
            _truncationNotice(
              context,
              text:
                  'Menampilkan ${services.length} dari ${result.meta.total} layanan',
              onSeeMore: _servicesLimit < _maxServicesLimit
                  ? _showMoreServices
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _buildAgents(BuildContext context) {
    final result = _agents!;
    final agents = result.agents;
    final isAgent = widget.user.role == UserRole.agent;
    return _card(
      context,
      title: 'Performa Agent',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (agents.isEmpty)
            _emptyText('Belum ada data agent.')
          else
            for (var i = 0; i < agents.length; i++)
              _kvRow(
                context,
                // `AgentStat` deliberately has no real name (see
                // model doc comment) — AGENT only ever sees itself.
                isAgent
                    ? 'Anda'
                    : 'Agent #${agents[i].id.substring(agents[i].id.length - 6).toUpperCase()}',
                '${formatRupiah(agents[i].totalRevenue)} (${agents[i].transactionCount}x)',
              ),
          if (result.meta.truncated)
            _truncationNotice(
              context,
              text:
                  'Menampilkan ${agents.length} dari ${result.meta.total} agent',
              onSeeMore: _agentsLimit < _maxAgentsLimit
                  ? _showMoreAgents
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _buildTransactions(BuildContext context) {
    final stats = _transactions!;
    return _card(
      context,
      title: 'Transaksi',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _countGroup(context, 'Status', stats.byStatus),
          const SizedBox(height: 12),
          _countGroup(context, 'Status Pembayaran', stats.byPaymentStatus),
          const SizedBox(height: 12),
          _countGroup(context, 'Metode Pembayaran', stats.byPaymentMethod),
        ],
      ),
    );
  }

  Widget _countGroup(
    BuildContext context,
    String title,
    List<CountItem> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        if (items.isEmpty)
          _emptyText('Belum ada data.')
        else
          ...items.map((i) => _kvRow(context, i.label, '${i.count}')),
      ],
    );
  }

  Widget _buildInventory(BuildContext context) {
    final result = _inventory!;
    final items = result.items;
    // This is a restock worklist, not a top-N ranking — unlike
    // Services/Agents, `meta.total` is always worth showing here, not
    // just when truncated, since a hidden count is misleading rather
    // than just incomplete (dashboard doc §3.6 "‼️").
    return _card(
      context,
      title: 'Stok Menipis (${result.meta.total})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (items.isEmpty)
            _emptyText('Tidak ada stok menipis.')
          else
            for (final i in items)
              _kvRow(
                context,
                '${i.name} (${i.branchName})',
                '${i.quantity}/${i.minimumStock}',
                valueColor: AppColors.warning,
              ),
          if (result.meta.truncated)
            _truncationNotice(
              context,
              text: '${items.length} dari ${result.meta.total} ditampilkan',
              onSeeMore: _inventoryLimit < _maxInventoryLimit
                  ? _showMoreInventory
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _truncationNotice(
    BuildContext context, {
    required String text,
    required VoidCallback? onSeeMore,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.secondaryText),
            ),
          ),
          if (onSeeMore != null)
            TextButton(
              onPressed: onSeeMore,
              child: const Text('Lihat lebih banyak'),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }

  Widget _statCard(BuildContext context, String label, String value) {
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
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, title),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _kvRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: valueColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _emptyText(String text) {
    return Text(text, style: const TextStyle(color: AppColors.secondaryText));
  }
}
