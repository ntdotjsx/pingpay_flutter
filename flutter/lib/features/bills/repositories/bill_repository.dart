import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../models/ocr_models.dart';

class BillRepository {
  final DioClient _client;

  BillRepository(this._client);

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
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return ReceiptOcrResultModel.fromJson(data);
  }
}
