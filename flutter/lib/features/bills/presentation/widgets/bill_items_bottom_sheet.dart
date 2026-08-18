import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/theme.dart';
import '../../models/ocr_models.dart';
import 'destructive_confirmation_sheet.dart';

class BillItemsBottomSheet extends StatefulWidget {
  final List<ReceiptItemModel> initialItems;
  final double billTotalAmount;
  final ValueChanged<List<ReceiptItemModel>> onItemsUpdated;

  const BillItemsBottomSheet({
    super.key,
    required this.initialItems,
    required this.billTotalAmount,
    required this.onItemsUpdated,
  });

  @override
  State<BillItemsBottomSheet> createState() => _BillItemsBottomSheetState();
}

class _BillItemsBottomSheetState extends State<BillItemsBottomSheet> {
  late List<ReceiptItemModel> _items;
  final Set<int> _selectedIndices = <int>{};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _items = List<ReceiptItemModel>.from(widget.initialItems);
  }

  double get _itemsTotal =>
      _items.fold(0.0, (acc, item) => acc + (item.amount * item.quantity));

  void _toggleItemSelection(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        if (_selectedIndices.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIndices.add(index);
        _isSelectionMode = true;
      }
    });
  }

  void _toggleSelectAll() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIndices.length == _items.length) {
        _selectedIndices.clear();
        _isSelectionMode = false;
      } else {
        _selectedIndices.addAll(List.generate(_items.length, (i) => i));
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _deleteSelectedItems() async {
    if (_selectedIndices.isEmpty) return;

    final count = _selectedIndices.length;
    final totalSelected = _selectedIndices.fold(
      0.0,
      (acc, idx) => acc + (_items[idx].amount * _items[idx].quantity),
    );

    final confirmed = await DestructiveConfirmationSheet.show(
      context,
      title: 'ลบ $count รายการที่เลือก?',
      message:
          'คุณกำลังจะลบรายการที่เลือกออกจากบิลนี้ การดำเนินการนี้ไม่สามารถย้อนกลับได้',
      confirmLabel: 'ลบ $count รายการ',
      cancelLabel: 'ยกเลิก',
      itemCount: count,
      totalAmount: totalSelected,
    );

    if (confirmed == true && mounted) {
      setState(() {
        final sortedIndices = _selectedIndices.toList()
          ..sort((a, b) => b.compareTo(a));
        for (final idx in sortedIndices) {
          if (idx < _items.length) {
            _items.removeAt(idx);
          }
        }
        _selectedIndices.clear();
        _isSelectionMode = false;
      });
      widget.onItemsUpdated(_items);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ลบ $count รายการเรียบร้อยแล้ว'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _deleteAllItems() async {
    if (_items.isEmpty) return;

    final confirmed = await DestructiveConfirmationSheet.show(
      context,
      title: 'ลบรายการทั้งหมด?',
      message:
          'คุณกำลังจะลบรายการสินค้าทั้งหมดออกจากบิลนี้ รายการที่ลบจะไม่สามารถกู้คืนได้',
      confirmLabel: 'ลบรายการทั้งหมด',
      cancelLabel: 'ยกเลิก',
      itemCount: _items.length,
      totalAmount: _itemsTotal,
    );

    if (confirmed == true && mounted) {
      setState(() {
        _items.clear();
        _selectedIndices.clear();
        _isSelectionMode = false;
      });
      widget.onItemsUpdated(_items);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ลบรายการทั้งหมดเรียบร้อยแล้ว'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  void _showAddOrEditItemDialog({
    ReceiptItemModel? itemToEdit,
    int? editIndex,
  }) {
    final nameController = TextEditingController(text: itemToEdit?.name ?? '');
    final priceController = TextEditingController(
      text: itemToEdit != null ? itemToEdit.amount.toStringAsFixed(2) : '',
    );
    final qtyController = TextEditingController(
      text: itemToEdit != null ? itemToEdit.quantity.toString() : '1',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          itemToEdit == null ? 'เพิ่มรายการอาหาร / สินค้า' : 'แก้ไขรายการ',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'ชื่อรายการ',
                  hintText: 'เช่น ข้าวมันไก่, ชาเขียว',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'ราคา (บาท)',
                        hintText: '0.00',
                        prefixText: '฿ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'จำนวน',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final price = double.tryParse(priceController.text.trim()) ?? 0.0;
              final qty = int.tryParse(qtyController.text.trim()) ?? 1;

              if (name.isEmpty || price <= 0 || qty <= 0) return;

              final newItem = ReceiptItemModel(
                name: name,
                amount: price,
                quantity: qty,
              );
              setState(() {
                if (editIndex != null) {
                  _items[editIndex] = newItem;
                } else {
                  _items.add(newItem);
                }
              });
              widget.onItemsUpdated(_items);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMismatch = (widget.billTotalAmount - _itemsTotal).abs() > 0.01;
    final allSelected =
        _items.isNotEmpty && _selectedIndices.length == _items.length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceTile1 : AppColors.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : AppColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Mode-Aware Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_isSelectionMode) ...[
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedIndices.clear();
                          _isSelectionMode = false;
                        });
                      },
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: const Text(
                        'ยกเลิก',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                    Text(
                      '${_selectedIndices.length} รายการที่เลือก',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.bodyOnDark : AppColors.ink,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _deleteSelectedItems,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppColors.error,
                      ),
                      label: Text(
                        'ลบ (${_selectedIndices.length})',
                        style: const TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    ),
                  ] else ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'รายการทั้งหมด ${_items.length} รายการ',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.bodyOnDark
                                : AppColors.ink,
                          ),
                        ),
                        Text(
                          'ยอดรวมรายการ: ฿${_itemsTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.inkMuted48,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (_items.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isSelectionMode = true;
                              });
                            },
                            child: const Text(
                              'เลือก',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => _showAddOrEditItemDialog(),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text(
                            'เพิ่ม',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Select All / Deselect All / Delete All toolbar in Selection Mode
            if (_items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _toggleSelectAll,
                      icon: Icon(
                        allSelected
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      label: Text(
                        allSelected ? 'ยกเลิกการเลือกทั้งหมด' : 'เลือกทั้งหมด',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    ),
                    if (!_isSelectionMode)
                      TextButton.icon(
                        onPressed: _deleteAllItems,
                        icon: const Icon(
                          Icons.delete_sweep_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                        label: const Text(
                          'ลบทั้งหมด',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      ),
                  ],
                ),
              ),

            // Mismatch Warning Banner
            if (isMismatch && _items.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ยอดรวมรายการ (฿${_itemsTotal.toStringAsFixed(2)}) ไม่ตรงกับยอดบิล (฿${widget.billTotalAmount.toStringAsFixed(2)}) อาจมี Vat/Service Charge',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Items List
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.42,
              ),
              child: _items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          'ยังไม่มีรายการสินค้า',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.bodyMuted
                                : AppColors.inkMuted48,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      shrinkWrap: true,
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (ctx, idx) {
                        final item = _items[idx];
                        final itemTotal = item.amount * item.quantity;
                        final isSelected = _selectedIndices.contains(idx);

                        return Material(
                          color: isSelected
                              ? AppColors.primary.withValues(
                                  alpha: isDark ? 0.2 : 0.08,
                                )
                              : (isDark
                                    ? AppColors.surfaceTile2
                                    : AppColors.canvasParchment),
                          shape: SmoothRectangleBorder(
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark
                                        ? Colors.white10
                                        : Colors.transparent),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                            borderRadius: const SmoothBorderRadius.all(
                              SmoothRadius(
                                cornerRadius: 14,
                                cornerSmoothing: 1.0,
                              ),
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleItemSelection(idx);
                              } else {
                                _showAddOrEditItemDialog(
                                  itemToEdit: item,
                                  editIndex: idx,
                                );
                              }
                            },
                            onLongPress: () => _toggleItemSelection(idx),
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  if (_isSelectionMode) ...[
                                    Container(
                                      width: 22,
                                      height: 22,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? AppColors.primary
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.inkMuted48,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check,
                                              size: 14,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isDark
                                                ? AppColors.bodyOnDark
                                                : AppColors.ink,
                                          ),
                                        ),
                                        Text(
                                          '฿${item.amount.toStringAsFixed(2)} x ${item.quantity}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.inkMuted48,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '฿${itemTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (!_isSelectionMode) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                      onPressed: () => _showAddOrEditItemDialog(
                                        itemToEdit: item,
                                        editIndex: idx,
                                      ),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'เสร็จสิ้น',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
