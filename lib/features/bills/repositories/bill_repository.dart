import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/bill_models.dart';
import '../models/ocr_models.dart';

class BillRepository {
  final DioClient _client;

  BillRepository(this._client);

  /// Upload receipt image to extract bill data via backend OCR
  Future<ReceiptOcrResultModel> scanReceiptOcr(File imageFile) async {
    final fileName = imageFile.path.split(Platform.pathSeparator).last;
    final formData = FormData.fromMap({
      'receipt': await MultipartFile.fromFile(
        imageFile.path,
        filename: fileName,
      ),
    });

    final response = await _client.post<Map<String, dynamic>>(
      '/api/v1/bills/ocr',
      data: formData,
      options: Options(
        sendTimeout: const Duration(seconds: 90),
        receiveTimeout: const Duration(seconds: 90),
      ),
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return ReceiptOcrResultModel.fromJson(data);
  }

  /// Create a new bill with selected friends
  Future<BillModel> createBill({
    required String title,
    required double totalAmount,
    required List<Map<String, dynamic>> participants,
    double ownerAmount = 0,
    String? description,
    String? allocationMethod,
    dynamic itemsBreakdown,
    String? receiptImageUrl,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/v1/bills',
      data: {
        'title': title,
        'totalAmount': totalAmount,
        'ownerAmount': ownerAmount,
        'participants': participants,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (allocationMethod != null) 'allocationMethod': allocationMethod,
        if (itemsBreakdown != null) 'itemsBreakdown': itemsBreakdown,
        if (receiptImageUrl != null && receiptImageUrl.isNotEmpty)
          'receiptImageUrl': receiptImageUrl,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return BillModel.fromJson(data);
  }

  /// Get all bills created by current user
  Future<List<BillModel>> getMyBills() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/v1/bills',
    );
    final data = (response.data?['data'] as List?) ?? [];
    return data.map((e) => BillModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get bill details by ID
  Future<BillModel> getBillDetails(String billId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/v1/bills/$billId',
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return BillModel.fromJson(data);
  }

  Future<BillModel> getBillById(String billId) => getBillDetails(billId);

  /// Edit whole bill metadata
  Future<BillModel> editBill({
    required String billId,
    String? title,
    String? description,
    double? totalAmount,
    dynamic itemsBreakdown,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/api/v1/bills/$billId',
      data: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (totalAmount != null) 'totalAmount': totalAmount,
        if (itemsBreakdown != null) 'itemsBreakdown': itemsBreakdown,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return BillModel.fromJson(data);
  }

  /// Edit individual participant amount and trigger auto-redistribution
  Future<BillModel> editParticipantAmount({
    required String billId,
    required String participantId,
    required double newAmount,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/api/v1/bills/$billId/participants/$participantId',
      data: {'amount': newAmount},
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return BillModel.fromJson(data);
  }

  /// Write off participant debt
  Future<Map<String, dynamic>> writeOffDebt({
    required String billId,
    required List<Map<String, dynamic>> participants,
    String? reason,
    String? idempotencyKey,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/v1/bills/$billId/write-offs',
      data: {
        'participants': participants,
        if (reason != null) 'reason': reason,
        if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
      },
    );

    return response.data?['data'] as Map<String, dynamic>? ?? {};
  }

  /// Adjust paid debt (refund/correction)
  Future<Map<String, dynamic>> adjustPaidDebt({
    required String billId,
    required String participantId,
    required double newAmount,
    String? reason,
    String? idempotencyKey,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/v1/bills/$billId/adjustments',
      data: {
        'participantId': participantId,
        'newAmount': newAmount,
        if (reason != null) 'reason': reason,
        if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
      },
    );

    return response.data?['data'] as Map<String, dynamic>? ?? {};
  }

  /// Cancel whole bill
  Future<Map<String, dynamic>> cancelBill({
    required String billId,
    String? reason,
  }) async {
    final response = await _client.delete<Map<String, dynamic>>(
      '/api/v1/bills/$billId',
      data: {if (reason != null) 'reason': reason},
    );

    return response.data?['data'] as Map<String, dynamic>? ?? {};
  }
}

final billRepositoryProvider = Provider<BillRepository>((ref) {
  final client = ref.watch(dioClientProvider);
  return BillRepository(client);
});
