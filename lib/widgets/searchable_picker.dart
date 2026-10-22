import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Opens a bottom sheet for picking one [T] out of a searchable list.
/// [onSearch] is called with the trimmed query — once immediately with
/// `''` so the sheet has something to show as soon as it opens, then
/// again (debounced) on every keystroke. Callers decide what that
/// means: an in-memory filter over an already-fetched list, or a live
/// API call per keystroke.
Future<T?> showSearchablePicker<T>({
  required BuildContext context,
  required String title,
  required String hintText,
  required Future<List<T>> Function(String query) onSearch,
  required String Function(T item) labelOf,
  String? Function(T item)? subtitleOf,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _SearchablePickerSheet<T>(
      title: title,
      hintText: hintText,
      onSearch: onSearch,
      labelOf: labelOf,
      subtitleOf: subtitleOf,
    ),
  );
}

enum _LoadState { loading, loaded, error }

class _SearchablePickerSheet<T> extends StatefulWidget {
  const _SearchablePickerSheet({
    required this.title,
    required this.hintText,
    required this.onSearch,
    required this.labelOf,
    this.subtitleOf,
  });

  final String title;
  final String hintText;
  final Future<List<T>> Function(String query) onSearch;
  final String Function(T item) labelOf;
  final String? Function(T item)? subtitleOf;

  @override
  State<_SearchablePickerSheet<T>> createState() =>
      _SearchablePickerSheetState<T>();
}

class _SearchablePickerSheetState<T> extends State<_SearchablePickerSheet<T>> {
  final _controller = TextEditingController();
  Timer? _debounce;

  _LoadState _state = _LoadState.loading;
  List<T> _results = const [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() {
      _state = _LoadState.loading;
      _errorMessage = null;
    });
    try {
      final results = await widget.onSearch(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _state = _LoadState.loaded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat data.';
        _state = _LoadState.error;
      });
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _search(value.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.85,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: _onChanged,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadState.error:
        return Center(
          child: Text(
            _errorMessage ?? 'Terjadi kesalahan.',
            style: const TextStyle(color: AppColors.error),
          ),
        );
      case _LoadState.loaded:
        if (_results.isEmpty) {
          return const Center(child: Text('Tidak ada hasil.'));
        }
        return ListView.separated(
          itemCount: _results.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = _results[index];
            final subtitle = widget.subtitleOf?.call(item);
            return ListTile(
              title: Text(widget.labelOf(item)),
              subtitle: subtitle == null ? null : Text(subtitle),
              onTap: () => Navigator.of(context).pop(item),
            );
          },
        );
    }
  }
}
