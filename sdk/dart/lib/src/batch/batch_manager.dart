import '../persistence/log_persistence.dart';
import '../policy/log_upload_policy.dart';

/// Groups persisted logs into batches according to policy and resource state.
class BatchManager {
  BatchManager({
    required FileLogPersistence persistence,
    required LogUploadPolicy policy,
  })  : _persistence = persistence,
        _policy = policy;

  final FileLogPersistence _persistence;
  final LogUploadPolicy _policy;

  Future<List<PendingBatch>> nextBatches() async {
    final batches = await _persistence.pendingBatches();
    if (_policy.maxBatchesPerCycle != null &&
        batches.length > _policy.maxBatchesPerCycle!) {
      return batches.take(_policy.maxBatchesPerCycle!).toList();
    }
    return batches;
  }
}
