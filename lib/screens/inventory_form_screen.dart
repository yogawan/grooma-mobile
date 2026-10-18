import 'package:flutter/material.dart';

import '../models/inventory.dart';
import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/inventory_service.dart';
import '../theme/app_colors.dart';

/// Create and edit share one form since most fields overlap, but the
/// two modes genuinely differ in what's editable (inventory doc §2 vs
/// §4): `itemCode`/`branchId`/initial `quantity` only make sense at
/// creation; `quantity` is never directly editable at all (only via
/// stock movements). Always pops the resulting [InventoryItem] (or
/// null if the user backed out without saving).
class InventoryFormScreen extends StatefulWidget {
  const InventoryFormScreen({
    super.key,
    required this.inventoryService,
    required this.user,
    this.existingItem,
  });

  final InventoryService inventoryService;
  final User user;
  final InventoryItem? existingItem;

  bool get isEditing => existingItem != null;

  @override
  State<InventoryFormScreen> createState() => _InventoryFormScreenState();
}

class _InventoryFormScreenState extends State<InventoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _itemCodeController = TextEditingController(
    text: widget.existingItem?.itemCode ?? '',
  );
  final _branchIdController = TextEditingController();
  late final _nameController = TextEditingController(
    text: widget.existingItem?.name ?? '',
  );
  late final _unitController = TextEditingController(
    text: widget.existingItem?.unit ?? 'PCS',
  );
  late final _quantityController = TextEditingController(text: '0');
  late final _unitCostController = TextEditingController(
    text: '${widget.existingItem?.unitCost ?? 0}',
  );
  late final _minimumStockController = TextEditingController(
    text: '${widget.existingItem?.minimumStock ?? 5}',
  );
  late final _supplierController = TextEditingController(
    text: widget.existingItem?.supplier ?? '',
  );

  late InventoryCategory _category =
      widget.existingItem?.category ?? InventoryCategory.other;

  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _itemCodeController.dispose();
    _branchIdController.dispose();
    _nameController.dispose();
    _unitController.dispose();
    _quantityController.dispose();
    _unitCostController.dispose();
    _minimumStockController.dispose();
    _supplierController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final InventoryItem item;
      if (widget.isEditing) {
        item = await widget.inventoryService.update(
          widget.existingItem!.id,
          name: _nameController.text.trim(),
          category: _category,
          unit: _unitController.text.trim(),
          unitCost: num.tryParse(_unitCostController.text.trim()) ?? 0,
          minimumStock: int.tryParse(_minimumStockController.text.trim()) ?? 5,
          supplier: _supplierController.text.trim().isEmpty
              ? null
              : _supplierController.text.trim(),
        );
      } else {
        item = await widget.inventoryService.create(
          itemCode: _itemCodeController.text.trim(),
          branchId: widget.user.role == UserRole.host
              ? _branchIdController.text.trim()
              : null,
          name: _nameController.text.trim(),
          category: _category,
          unit: _unitController.text.trim(),
          quantity: int.tryParse(_quantityController.text.trim()) ?? 0,
          unitCost: num.tryParse(_unitCostController.text.trim()) ?? 0,
          minimumStock: int.tryParse(_minimumStockController.text.trim()) ?? 5,
          supplier: _supplierController.text.trim().isEmpty
              ? null
              : _supplierController.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop(item);
    } on ApiException catch (e) {
      setState(() {
        _submitting = false;
        _errorMessage = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHost = widget.user.role == UserRole.host;

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit Item' : 'Item Baru')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.isEditing) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Belum ada katalog cabang di app ini — isi Branch ID secara manual.',
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _itemCodeController,
                  decoration: const InputDecoration(labelText: 'Kode Item'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Kode item wajib diisi'
                      : null,
                ),
                const SizedBox(height: 16),
                // AGENT always uses their session branch — the field is
                // ignored server-side either way, so hiding it avoids
                // implying AGENT has a choice here (inventory doc §9).
                if (isHost)
                  TextFormField(
                    controller: _branchIdController,
                    decoration: const InputDecoration(labelText: 'Branch ID'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Branch ID wajib diisi untuk Host'
                        : null,
                  ),
                if (isHost) const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama Item'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Nama wajib diisi'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<InventoryCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: InventoryCategory.values
                    .map(
                      (c) => DropdownMenuItem(value: c, child: Text(c.label)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _unitController,
                decoration: const InputDecoration(labelText: 'Satuan'),
              ),
              if (!widget.isEditing) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stok Awal'),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _unitCostController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: false,
                ),
                decoration: const InputDecoration(
                  labelText: 'Harga Satuan (Rp)',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _minimumStockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stok Minimum'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _supplierController,
                decoration: const InputDecoration(
                  labelText: 'Supplier (opsional)',
                ),
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
                    : Text(widget.isEditing ? 'Simpan' : 'Buat Item'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
