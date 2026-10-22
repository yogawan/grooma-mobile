import 'package:flutter/material.dart';

import '../models/pagination.dart';
import '../models/service_item.dart';
import '../services/api_exception.dart';
import '../services/service_catalog_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/message_view.dart';
import '../widgets/status_badge.dart';
import 'service_detail_screen.dart';
import 'service_form_screen.dart';

enum _LoadState { loading, loaded, locked, error }

/// This screen is HOST-only UI (reached from the Kelola hub), so the
/// list always includes inactive services too (Kelola doc §3.1: only
/// AGENT's view is filtered to active-only, server-side, and AGENT
/// never opens this screen). Paginated now (AUTH doc §2.1.4), default
/// 20 rows per page, no client-side search added for this first pass.
class ServiceListScreen extends StatefulWidget {
  const ServiceListScreen({super.key, required this.serviceCatalogService});

  final ServiceCatalogService serviceCatalogService;

  @override
  State<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  List<ServiceItem> _services = const [];
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
      final result = await widget.serviceCatalogService.list(page: _page);
      setState(() {
        _services = result.services;
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
    final created = await Navigator.of(context).push<ServiceItem>(
      MaterialPageRoute(
        builder: (_) => ServiceFormScreen(
          serviceCatalogService: widget.serviceCatalogService,
        ),
      ),
    );
    if (created != null) _load();
  }

  Future<void> _openDetail(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServiceDetailScreen(
          serviceCatalogService: widget.serviceCatalogService,
          serviceId: id,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Layanan')),
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
          title: 'Gagal memuat layanan',
          message: _errorMessage ?? 'Terjadi kesalahan.',
          onRetry: _load,
        );
      case _LoadState.loaded:
        if (_services.isEmpty) {
          return const Center(child: Text('Belum ada layanan.'));
        }
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView.separated(
            itemCount: _services.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, thickness: 1, color: AppColors.border),
            itemBuilder: (context, index) =>
                _buildRow(context, _services[index]),
          ),
        );
    }
  }

  Widget _buildRow(BuildContext context, ServiceItem service) {
    return ListTile(
      onTap: () => _openDetail(service.id),
      title: Row(
        children: [
          Expanded(child: Text(service.name)),
          if (!service.isActive) ...[
            const SizedBox(width: 8),
            const StatusBadge(
              label: 'Nonaktif',
              color: AppColors.secondaryText,
            ),
          ],
        ],
      ),
      subtitle: Text(service.serviceCode),
      trailing: Text(
        formatRupiah(service.price),
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(fontWeight: FontWeight.w600),
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
