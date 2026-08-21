import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ocr_models.dart';
import '../repositories/bill_repository.dart';

class OcrScanState {
  final bool isScanning;
  final ReceiptOcrResultModel? result;
  final String? errorMessage;

  const OcrScanState({this.isScanning = false, this.result, this.errorMessage});

  OcrScanState copyWith({
    bool? isScanning,
    ReceiptOcrResultModel? result,
    String? errorMessage,
  }) {
    return OcrScanState(
      isScanning: isScanning ?? this.isScanning,
      result: result ?? this.result,
      errorMessage: errorMessage,
    );
  }
}

class OcrScanNotifier extends StateNotifier<OcrScanState> {
  final BillRepository _repo;

  OcrScanNotifier(this._repo) : super(const OcrScanState());

  Future<ReceiptOcrResultModel?> scanReceipt(File file) async {
    state = state.copyWith(isScanning: true, errorMessage: null);
    try {
      final result = await _repo.scanReceiptOcr(file);
      state = state.copyWith(isScanning: false, result: result);
      return result;
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        errorMessage:
            'การสแกนใบเสร็จขัดข้อง: ${e.toString().replaceAll("Exception: ", "")}',
      );
      return null;
    }
  }

  void reset() {
    state = const OcrScanState();
  }
}

final ocrScanProvider = StateNotifierProvider<OcrScanNotifier, OcrScanState>((
  ref,
) {
  final repo = ref.watch(billRepositoryProvider);
  return OcrScanNotifier(repo);
});
