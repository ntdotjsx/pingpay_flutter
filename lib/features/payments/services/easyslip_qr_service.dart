import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thai_promptpay/thai_promptpay.dart';
import '../../../../core/network/dio_client.dart';
import '../../auth/providers/auth_provider.dart';

class EasySlipQrResult {
  final bool isSuccess;
  final String? imageBase64;
  final String? payload;
  final String? errorMessage;
  final bool isFallback;

  const EasySlipQrResult({
    required this.isSuccess,
    this.imageBase64,
    this.payload,
    this.errorMessage,
    this.isFallback = false,
  });
}

class EasySlipQrService {
  final DioClient _client;

  EasySlipQrService(this._client);

  /// Generates QR via EasySlip backend API with automatic local fallback
  Future<EasySlipQrResult> generateQr({
    required String type, // 'PROMPTPAY', 'TRUEMONEY', 'KSHOP', 'MAE_MANEE', 'TUNGNGERN'
    String? msisdn,
    String? natId,
    String? eWalletId,
    String? ref1,
    String? merchantName,
    double? amount,
  }) async {
    final cleanPhone = msisdn?.replaceAll(RegExp(r'[^0-9]'), '');
    final cleanNatId = natId?.replaceAll(RegExp(r'[^0-9]'), '');
    final cleanEWallet = eWalletId?.replaceAll(RegExp(r'[^0-9]'), '');

    try {
      final response = await _client.post(
        '/api/v1/payments/qr/generate',
        data: {
          'type': type,
          if (cleanPhone != null && cleanPhone.isNotEmpty) 'msisdn': cleanPhone,
          if (cleanNatId != null && cleanNatId.isNotEmpty) 'natId': cleanNatId,
          if (cleanEWallet != null && cleanEWallet.isNotEmpty) 'eWalletId': cleanEWallet,
          if (ref1 != null && ref1.isNotEmpty) 'ref1': ref1,
          if (merchantName != null && merchantName.isNotEmpty) 'merchantName': merchantName,
          if (amount != null && amount > 0) 'amount': amount,
        },
      );

      final data = response.data;
      if (data != null && data['success'] == true && data['data'] != null) {
        final qrData = data['data'];
        return EasySlipQrResult(
          isSuccess: true,
          imageBase64: qrData['image'] as String?,
          payload: qrData['payload'] as String?,
        );
      }
    } catch (e) {
      debugPrint('[EasySlipQrService] Backend generate error, falling back locally: $e');
    }

    // ── Local Fallback using thai_promptpay if EasySlip backend fails ──
    try {
      final targetId = cleanPhone ?? cleanNatId ?? cleanEWallet;
      if (targetId != null && targetId.isNotEmpty) {
        final satang = (amount != null && amount > 0) ? (amount * 100).round() : null;
        String localPayload;

        if (targetId.length == 13) {
          localPayload = encodePromptPay(
            target: PromptPayTarget(PromptPayType.nationalId, targetId),
            amountSatang: satang,
          );
        } else if (targetId.length == 15) {
          localPayload = encodePromptPay(
            target: PromptPayTarget(PromptPayType.eWallet, targetId),
            amountSatang: satang,
          );
        } else {
          localPayload = promptPayMobile(targetId, amountSatang: satang);
        }

        return EasySlipQrResult(
          isSuccess: true,
          payload: localPayload,
          isFallback: true,
        );
      }
    } catch (fallbackErr) {
      debugPrint('[EasySlipQrService] Local fallback error: $fallbackErr');
    }

    return const EasySlipQrResult(
      isSuccess: false,
      errorMessage: 'ไม่สามารถสร้าง QR Code ได้ กรุณาตรวจสอบข้อมูลบัญชีผู้รับ',
    );
  }
}

final easySlipQrServiceProvider = Provider<EasySlipQrService>((ref) {
  final client = ref.watch(dioClientProvider);
  return EasySlipQrService(client);
});
