/// Declarative configuration describing upload cadence and constraints.
class LogUploadPolicy {
  const LogUploadPolicy({this.maxBatchesPerCycle});

  /// Optional limit for how many batches should be processed per cycle.
  final int? maxBatchesPerCycle;
}
