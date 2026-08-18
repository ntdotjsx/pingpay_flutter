import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../models/bill_models.dart';
import '../providers/bill_provider.dart';
import '../repositories/bill_repository.dart';

class BillDetailScreen extends ConsumerStatefulWidget {
  final String billId;

  const BillDetailScreen({super.key, required this.billId});

  @override
  ConsumerState<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends ConsumerState<BillDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final billAsync = ref.watch(billDetailProvider(widget.billId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.surfaceBlack
          : const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: const Text(
          'รายละเอียดบิล (Bill Detail)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: billAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.receipt_long_rounded,
                size: 60,
                color: Colors.grey,
              ),
              const SizedBox(height: 12),
              Text('โหลดข้อมูลบิลไม่สำเร็จ: $err'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(billDetailProvider(widget.billId)),
                child: const Text('ลองใหม่'),
              ),
            ],
          ),
        ),
        data: (bill) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Summary Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: ShapeDecoration(
                    color: isDark ? AppColors.surfaceTile1 : Colors.white,
                    shape: const SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 22, cornerSmoothing: 1.0),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              bill.title ?? 'บิลค่าใช้จ่าย',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _buildStatusBadge(bill.status),
                        ],
                      ),
                      if (bill.description != null &&
                          bill.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          bill.description!,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 14),

                      // Financial Accounting Triad: Original = Paid + WrittenOff + Outstanding
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildAccountingColumn(
                            'ยอดรวมทั้งหมด',
                            '฿${bill.totalAmount.toStringAsFixed(2)}',
                            const Color(0xFF1D1D1F),
                          ),
                          _buildAccountingColumn(
                            'ชำระแล้ว',
                            '฿${bill.totalPaidAmount.toStringAsFixed(2)}',
                            const Color(0xFF2E7D32),
                          ),
                          _buildAccountingColumn(
                            'ยกหนี้ให้',
                            '฿${bill.totalWrittenOffAmount.toStringAsFixed(2)}',
                            const Color(0xFF6B7280),
                          ),
                          _buildAccountingColumn(
                            'คงค้าง',
                            '฿${bill.totalOutstandingAmount.toStringAsFixed(2)}',
                            const Color(0xFFFF5000),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Participants Portion Details
                const Text(
                  'รายการลูกหนี้ / ผู้ร่วมหาร',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: bill.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final item = bill.items[idx];
                    final debtorName = item.debtor?.displayName ?? 'เพื่อน';
                    final isPaidLocked = item.isFullyPaid || item.isLocked;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: ShapeDecoration(
                        color: isDark ? AppColors.surfaceTile1 : Colors.white,
                        shape: const SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius.all(
                            SmoothRadius(
                              cornerRadius: 18,
                              cornerSmoothing: 1.0,
                            ),
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFFFFF0E6),
                                child: Text(
                                  debtorName.isNotEmpty
                                      ? debtorName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF5000),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      debtorName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      'รหัส: ${item.debtor?.userCode ?? "-"}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildItemStatusBadge(item.status),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),

                          // Portions details
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ยอดส่วนแบ่ง: ฿${item.currentAmount.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              Text(
                                'จ่ายแล้ว: ฿${item.amountPaid.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF2E7D32),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (item.amountWrittenOff > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'ยกหนี้ให้ (Write-off):',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  '฿${item.amountWrittenOff.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'ยอดคงค้างสุทธิ:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '฿${item.outstandingAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF5000),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Actions: Edit / Write-Off / Lock Indicator
                          if (isPaidLocked)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    '🔒 ยอดชำระแล้วถูกล็อค (Paid amount locked)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _showEditAmountDialog(item),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 14,
                                    ),
                                    label: const Text(
                                      'แก้ไขยอด',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showWriteOffDialog(item),
                                    icon: const Icon(
                                      Icons.money_off_rounded,
                                      size: 14,
                                      color: Color(0xFFE53935),
                                    ),
                                    label: const Text(
                                      'ยกหนี้ให้',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFE53935),
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccountingColumn(String title, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    String text = 'ยังไม่ชำระ';
    Color bg = const Color(0xFFFFEBEE);
    Color fg = const Color(0xFFC62828);

    switch (status) {
      case 'fully_paid':
        text = 'ชำระครบแล้ว';
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        break;
      case 'partially_paid':
        text = 'ชำระบางส่วน';
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        break;
      case 'fully_written_off':
        text = 'ยกหนี้ครบทั้งหมด';
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
        break;
      case 'partially_written_off':
        text = 'ยกหนี้บางส่วน';
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildItemStatusBadge(String status) {
    String text = 'ยังไม่ชำระ';
    Color bg = const Color(0xFFFFEBEE);
    Color fg = const Color(0xFFC62828);

    if (status == 'paid') {
      text = 'ชำระแล้ว';
      bg = const Color(0xFFE8F5E9);
      fg = const Color(0xFF2E7D32);
    } else if (status == 'partially_paid') {
      text = 'ชำระบางส่วน';
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFE65100);
    } else if (status == 'written_off') {
      text = 'ยกหนี้ให้';
      bg = Colors.grey.shade200;
      fg = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  void _showEditAmountDialog(BillItemParticipantModel item) {
    final controller = TextEditingController(
      text: item.currentAmount.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('แก้ไขยอดของ ${item.debtor?.displayName ?? "ผู้ใช้"}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'เมื่อเปลี่ยนยอดของคนนี้ ระบบจะเฉลี่ยยอดที่เหลือให้เพื่อนคนอื่นที่ยังไม่จ่ายโดยอัตโนมัติ',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'ยอดใหม่ (บาท)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newAmt = double.tryParse(controller.text.trim());
              if (newAmt == null || newAmt < 0) return;

              Navigator.pop(ctx);
              try {
                final repo = ref.read(billRepositoryProvider);
                await repo.editParticipantAmount(
                  billId: widget.billId,
                  participantId: item.id,
                  newAmount: newAmt,
                );
                ref.invalidate(billDetailProvider(widget.billId));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('อัปเดตยอดและเฉลี่ยหนี้เรียบร้อย'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('แก้ไขไม่สำเร็จ: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5000),
              foregroundColor: Colors.white,
            ),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  void _showWriteOffDialog(BillItemParticipantModel item) {
    final controller = TextEditingController(
      text: item.outstandingAmount.toStringAsFixed(2),
    );
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'ยกหนี้ให้ ${item.debtor?.displayName ?? "ผู้ใช้"} (Write-off)',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ยอดคงค้างปัจจุบัน: ฿${item.outstandingAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'การยกหนี้จะถูกบันทึกในประวัติการเงินอย่างโปร่งใส และไม่นับเป็นรายรับที่ชำระแล้ว',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'จำนวนเงินที่ต้องการยกหนี้ (บาท)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: 'เหตุผล (ถ้ามี)',
                  hintText: 'เช่น เลี้ยงเนื่องในวันเกิด',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
            onPressed: () async {
              final writeOffAmt = double.tryParse(controller.text.trim());
              if (writeOffAmt == null ||
                  writeOffAmt <= 0 ||
                  writeOffAmt > item.outstandingAmount) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('ยอดเงินยกหนี้ไม่ถูกต้อง'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(ctx);
              try {
                final repo = ref.read(billRepositoryProvider);
                await repo.writeOffDebt(
                  billId: widget.billId,
                  participants: [
                    {'participantId': item.id, 'amount': writeOffAmt},
                  ],
                  reason: reasonController.text.trim(),
                );
                ref.invalidate(billDetailProvider(widget.billId));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('ยกหนี้ ฿$writeOffAmt เรียบร้อย'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('ยกหนี้ไม่สำเร็จ: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            child: const Text('ยืนยันยกหนี้'),
          ),
        ],
      ),
    );
  }
}
