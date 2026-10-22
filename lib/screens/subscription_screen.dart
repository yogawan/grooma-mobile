import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/pagination.dart';
import '../models/subscription.dart';
import '../services/api_exception.dart';
import '../services/subscription_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/message_view.dart';
import '../widgets/status_badge.dart';

enum _LoadState { loading, loaded, error }

/// This module never 402s (`EXEMPT_ALL`, Kelola doc §0) — it's the one
/// escape hatch a lapsed HOST needs, so there's no locked state here
/// unlike every other Kelola screen.
///
/// `GET /subscription/invoices/:id` is permanently broken (doc §4.4:
/// always `403`, even for the rightful owner), so paying an invoice
/// shows its QR straight from the already-fetched list item instead of
/// navigating to a detail screen that would just fail.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key, required this.subscriptionService});

  final SubscriptionService subscriptionService;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  int _page = 1;
  _LoadState _state = _LoadState.loading;
  String? _errorMessage;
  Subscription? _subscription;
  List<Invoice> _invoices = const [];
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
      final subscriptionFuture = widget.subscriptionService.getStatus();
      final invoicesFuture = widget.subscriptionService.listInvoices(
        page: _page,
      );
      final subscription = await subscriptionFuture;
      final invoicePage = await invoicesFuture;
      setState(() {
        _subscription = subscription;
        _invoices = invoicePage.invoices;
        _pagination = invoicePage.pagination;
        _state = _LoadState.loaded;
      });
    } on ApiException catch (e) {
      setState(() {
        _state = _LoadState.error;
        _errorMessage = e.message;
      });
    }
  }

  void _changePage(int delta) {
    setState(() => _page += delta);
    _load();
  }

  void _showInvoiceQr(Invoice invoice) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              invoice.invoiceCode,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              formatRupiah(invoice.amount),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (invoice.qrCodeUrl != null)
              Image.network(
                invoice.qrCodeUrl!,
                width: 220,
                height: 220,
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  width: 220,
                  height: 220,
                  child: Center(child: Icon(LucideIcons.qrCode, size: 96)),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Jatuh tempo ${formatDateTime(invoice.dueAt)}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.secondaryText),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _load();
              },
              child: const Text('Saya Sudah Bayar — Refresh Status'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription & Billing')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadState.error:
        return MessageView(
          icon: LucideIcons.circleAlert,
          iconColor: AppColors.error,
          title: 'Gagal memuat subscription',
          message: _errorMessage ?? 'Terjadi kesalahan.',
          onRetry: _load,
        );
      case _LoadState.loaded:
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatusCard(context),
              const SizedBox(height: 24),
              Text(
                'Riwayat Invoice',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (_invoices.isEmpty)
                const Text('Belum ada invoice.')
              else
                ..._invoices.map(
                  (invoice) => _buildInvoiceRow(context, invoice),
                ),
              if (_pagination != null) _buildPager(context, _pagination!),
            ],
          ),
        );
    }
  }

  Widget _buildStatusCard(BuildContext context) {
    final subscription = _subscription;
    if (subscription == null) {
      // doc §4.2: null here is a normal "no subscription record yet"
      // state on a fresh deployment, not an error or a locked account.
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text('Belum ada data langganan untuk bisnis ini.'),
      );
    }

    final statusColor = switch (subscription.status) {
      SubscriptionStatus.active => AppColors.success,
      SubscriptionStatus.pastDue => AppColors.warning,
      SubscriptionStatus.expired => AppColors.error,
      SubscriptionStatus.cancelled => AppColors.error,
    };

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                subscription.plan.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              StatusBadge(label: subscription.status.label, color: statusColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${formatRupiah(subscription.plan.price)} / ${subscription.plan.billingCycle}',
          ),
          const SizedBox(height: 8),
          Text(
            'Periode: ${formatDate(subscription.currentPeriodStart)} - '
            '${formatDate(subscription.currentPeriodEnd)}',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.secondaryText),
          ),
          if (subscription.status.isLocked)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                subscription.graceEndsAt != null
                    ? 'Akses terkunci. Masa tenggang sampai ${formatDateTime(subscription.graceEndsAt!)}.'
                    : 'Akses terkunci. Bayar invoice di bawah untuk memulihkan akses.',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInvoiceRow(BuildContext context, Invoice invoice) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(invoice.invoiceCode),
        subtitle: Text(
          '${formatDate(invoice.periodStart)} - ${formatDate(invoice.periodEnd)} • ${invoice.status}',
        ),
        trailing: invoice.isPayable
            ? FilledButton(
                onPressed: () => _showInvoiceQr(invoice),
                child: const Text('Bayar'),
              )
            : Text(formatRupiah(invoice.amount)),
      ),
    );
  }

  Widget _buildPager(BuildContext context, Pagination pagination) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
