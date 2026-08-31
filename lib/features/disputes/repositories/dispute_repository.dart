import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/dispute_model.dart';

final disputeRepositoryProvider = Provider<DisputeRepository>((ref) {
  final client = ref.watch(dioClientProvider);
  return DisputeRepository(client);
});

class DisputeRepository {
  final DioClient _client;

  DisputeRepository(this._client);

  /// Debtor raises a dispute for a bill item
  Future<DisputeModel> raiseDispute({
    required String billItemId,
    required String reason,
    String? evidenceUrl,
  }) async {
    try {
      final response = await _client.post('/api/v1/disputes', data: {
        'billItemId': billItemId,
        'reason': reason,
        if (evidenceUrl != null && evidenceUrl.isNotEmpty) 'evidenceUrl': evidenceUrl,
      });

      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] != null) {
        return DisputeModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw Exception('Invalid response format');
    } catch (e) {
      debugPrint('Error raising dispute: $e');
      rethrow;
    }
  }

  /// Creditor submits counter-evidence for a dispute
  Future<DisputeModel> submitCreditorEvidence({
    required String disputeId,
    String? note,
    String? evidenceUrl,
  }) async {
    try {
      final response = await _client.post('/api/v1/disputes/$disputeId/evidence', data: {
        if (note != null && note.isNotEmpty) 'note': note,
        if (evidenceUrl != null && evidenceUrl.isNotEmpty) 'evidenceUrl': evidenceUrl,
      });

      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] != null) {
        return DisputeModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw Exception('Invalid response format');
    } catch (e) {
      debugPrint('Error submitting creditor evidence: $e');
      rethrow;
    }
  }

  /// Get details of a specific dispute
  Future<DisputeModel> getDisputeDetail(String disputeId) async {
    try {
      final response = await _client.get('/api/v1/disputes/$disputeId');
      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] != null) {
        return DisputeModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw Exception('Dispute not found');
    } catch (e) {
      debugPrint('Error getting dispute detail: $e');
      rethrow;
    }
  }

  /// List user's active/past disputes
  Future<List<DisputeModel>> getUserDisputes() async {
    try {
      final response = await _client.get('/api/v1/disputes');
      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] is List) {
        final list = data['data'] as List;
        return list.map((json) => DisputeModel.fromJson(json as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting user disputes: $e');
      return [];
    }
  }
}
