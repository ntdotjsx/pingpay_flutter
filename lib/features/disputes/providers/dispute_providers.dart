import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dispute_model.dart';
import '../repositories/dispute_repository.dart';

final userDisputesProvider = FutureProvider.autoDispose<List<DisputeModel>>((ref) async {
  final repository = ref.watch(disputeRepositoryProvider);
  return repository.getUserDisputes();
});

final disputeDetailProvider = FutureProvider.autoDispose.family<DisputeModel, String>((ref, disputeId) async {
  final repository = ref.watch(disputeRepositoryProvider);
  return repository.getDisputeDetail(disputeId);
});
