import 'package:flutter/material.dart';

import '../models/inventory.dart';
import '../services/api_exception.dart';
import '../services/inventory_service.dart';
import '../theme/app_colors.dart';

/// Three distinct field sets behind one `movementType` selector, not
/// one generic "quantity" field — IN/OUT take a positive delta,
/// ADJUSTMENT takes an absolute end value, and sending the wrong field
/// for the chosen type is a 400 server-side (inventory doc §7, §9).
/// Pops the updated [InventoryItem] on success — the record-movement
/// response already carries it, no extra refetch needed.
class StockMovementFormScreen extends StatefulWidget {
  const StockMovementFormScreen({
    super.key,
    required this.inventoryService,
    required this.itemId,
    required this.currentQuantity,
  });

  final InventoryService inventoryService;
  final String itemId;
  final int currentQuantity;

  @override
  State<StockMovementFormScreen> createState() =>
      _StockMovementFormScreenState();
}

class _StockMovementFormScreenState extends State<StockMovementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();

  StockMovementType _type = StockMovementType.stockIn;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final amount = int.parse(_amountController.text.trim());
      final reason = _reasonController.text.trim();
      final result = switch (_type) {
        StockMovementType.stockIn => await widget.inventoryService.recordIn(
          widget.itemId,
          quantity: amount,
          reason: reason,
        ),
        StockMovementType.stockOut => await widget.inventoryService.recordOut(
          widget.itemId,
          quantity: amount,
          reason: reason,
        ),
        StockMovementType.adjustment =>
          await widget.inventoryService.recordAdjustment(
            widget.itemId,
            newQuantity: amount,
            reason: reason,
          ),
      };
      if (mounted) Navigator.of(context).pop(result.item);
    } on ApiException catch (e) {
      setState(() {
        _submitting = false;
        _errorMessage = e.message;
      });
    }
  }

  String get _amountLabel =>
      _type == StockMovementType.adjustment ? 'Stok Akhir' : 'Jumlah';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catat Pergerakan Stok')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Stok saat ini: ${widget.currentQuantity}',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.secondaryText),
              ),
              const SizedBox(height: 16),
              SegmentedButton<StockMovementType>(
                segments: StockMovementType.values
                    .map((t) => ButtonSegment(value: t, label: Text(t.label)))
                    .toList(),
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: _amountLabel),
                validator: (value) {
                  final parsed = int.tryParse(value?.trim() ?? '');
                  if (parsed == null) return 'Masukkan angka yang valid';
                  if (_type == StockMovementType.adjustment) {
                    return parsed < 0 ? 'Tidak boleh negatif' : null;
                  }
                  return parsed <= 0 ? 'Harus lebih dari 0' : null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Alasan'),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return 'Alasan wajib diisi';
                  if (trimmed.length > 500) return 'Maksimal 500 karakter';
                  return null;
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
