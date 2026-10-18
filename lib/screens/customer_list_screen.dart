import 'dart:async';

import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/customer_service.dart';
import '../theme/app_colors.dart';
import '../widgets/message_view.dart';
import '../widgets/status_badge.dart';
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';

enum _LoadState { idle, loading, loaded, error }

const _minQueryLength = 2;

/// Search-first by design — the backend has no pagination on this
/// endpoint at all, so an empty/trivial query would fetch the entire
/// cross-branch customer base in one response (customer doc §2). A
/// query shorter than [_minQueryLength] never reaches the network.
class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({
    super.key,
    required this.customerService,
    required this.user,
  });

  final CustomerService customerService;
  final User user;

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  _LoadState _state = _LoadState.idle;
  String? _errorMessage;
  List<Customer> _results = const [];

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < _minQueryLength) {
      setState(() {
        _state = _LoadState.idle;
        _results = const [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() {
      _state = _LoadState.loading;
      _errorMessage = null;
    });
    try {
      final results = await widget.customerService.search(search: query);
      setState(() {
        _results = results;
        _state = _LoadState.loaded;
      });
    } on ApiException catch (e) {
      setState(() {
        _state = _LoadState.error;
        _errorMessage = e.message;
      });
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<Customer>(
      MaterialPageRoute(
        builder: (_) => CustomerFormScreen(
          customerService: widget.customerService,
          isHost: widget.user.role == UserRole.host,
        ),
      ),
    );
    if (created != null) _openDetail(created.id);
  }

  void _openDetail(String id) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerDetailScreen(
          customerService: widget.customerService,
          customerId: id,
          user: widget.user,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Cari nama atau nomor HP',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_state) {
      case _LoadState.idle:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Ketik minimal $_minQueryLength karakter (nama atau nomor HP) untuk mencari.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.secondaryText),
            ),
          ),
        );
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadState.error:
        return MessageView(
          icon: Icons.error_outline,
          iconColor: AppColors.error,
          title: 'Gagal mencari customer',
          message: _errorMessage ?? 'Terjadi kesalahan.',
          onRetry: () => _search(_searchController.text.trim()),
        );
      case _LoadState.loaded:
        if (_results.isEmpty) {
          return const Center(child: Text('Tidak ada customer yang cocok.'));
        }
        return ListView.separated(
          itemCount: _results.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) => _buildRow(context, _results[index]),
        );
    }
  }

  Widget _buildRow(BuildContext context, Customer customer) {
    return ListTile(
      onTap: () => _openDetail(customer.id),
      title: Row(
        children: [
          Expanded(child: Text(customer.name)),
          if (!customer.isActive) ...[
            const SizedBox(width: 8),
            const StatusBadge(
              label: 'Nonaktif',
              color: AppColors.secondaryText,
            ),
          ],
        ],
      ),
      subtitle: Text(customer.phone ?? 'Tanpa nomor HP'),
      trailing: Text(
        '${customer.loyaltyPoints} poin',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: AppColors.secondaryText),
      ),
    );
  }
}
