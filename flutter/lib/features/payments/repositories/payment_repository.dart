import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/payment_models.dart';

class PaymentRepository {
  final DioClient _client;

  PaymentRepository(this._client);

  /// Fetch all outstanding and historical debts owed by the current user
  Future<UserDebtsResponseModel> getUserDebtsAndSummary() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/v1/bills/debts',
    );
    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return UserDebtsResponseModel.fromJson(data);
  }

  /// Submit payment with transfer slip for a specific bill and participant debt
  Future<CreatePaymentResultModel> submitPaymentWithSlip({
    required String billId,
    required String participantId,
    required double amount,
    File? slipFile,
    String? qrData,
    String? method,
    String? channel,
    String? idempotencyKey,
  }) async {
    dynamic bodyData;

    if (slipFile != null) {
      final fileName = slipFile.path.split(Platform.pathSeparator).last;
      bodyData = FormData.fromMap({
        'participantId': participantId,
        'amount': amount,
        if (method != null) 'method': method,
        if (channel != null) 'channel': channel,
        if (qrData != null) 'qrData': qrData,
        if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
        'slip': await MultipartFile.fromFile(slipFile.path, filename: fileName),
      });
    } else {
      bodyData = {
        'participantId': participantId,
        'amount': amount,
        if (method != null) 'method': method,
        if (channel != null) 'channel': channel,
        if (qrData != null) 'qrData': qrData,
        if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
      };
    }

    final response = await _client.post<Map<String, dynamic>>(
      '/api/v1/bills/$billId/payments',
      data: bodyData,
      options: Options(
        sendTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(seconds: 45),
      ),
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return CreatePaymentResultModel.fromJson(data);
  }

  /// Get chronological installments/payment history for a bill
  Future<List<PaymentInstallmentModel>> getBillPaymentHistory(
    String billId,
  ) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/v1/bills/$billId/payments',
    );

    final data = (response.data?['data'] as List?) ?? [];
    return data
        .map((e) => PaymentInstallmentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Bill Owner confirms receipt of funds
  Future<Map<String, dynamic>> confirmPayment({
    required String paymentId,
    String? idempotencyKey,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/v1/bills/payments/$paymentId/confirm',
      data: {if (idempotencyKey != null) 'idempotencyKey': idempotencyKey},
    );

    return response.data ?? {};
  }

  /// Bill Owner rejects payment slip
  Future<Map<String, dynamic>> rejectPayment({
    required String paymentId,
    required String reason,
    String? idempotencyKey,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/v1/bills/payments/$paymentId/reject',
      data: {
        'reason': reason,
        if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
      },
    );

    return response.data ?? {};
  }

  /// Fetch all receivables (debts other users owe to current user as bill owner)
  Future<UserReceivablesResponseModel> getUserReceivablesAndSummary() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/v1/bills/receivables',
    );
    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return UserReceivablesResponseModel.fromJson(data);
  }

  /// Debtor acknowledges/accepts debt by swiping
  Future<Map<String, dynamic>> acknowledgeDebt(String billItemId) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/v1/bills/debts/$billItemId/acknowledge',
    );
    return response.data ?? {};
  }
}

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final client = ref.watch(dioClientProvider);
  return PaymentRepository(client);
});
