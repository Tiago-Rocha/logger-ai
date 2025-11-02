import '../persistence/log_persistence.dart';

/// Coordinates the preparation and dispatch of log batches to the backend.
abstract class UploadManager {
  /// Performs a scheduled upload attempt for the provided [batches].
  Future<UploadResult> upload(List<PendingBatch> batches);
}

/// Outcome returned from an upload attempt.
class UploadResult {
  UploadResult._({
    required this.isSuccess,
    required this.batchHighWaterMarks,
    this.error,
  });

  /// Indicates whether the upload completed successfully.
  final bool isSuccess;

  /// High-water marks reported per uploaded batch filename.
  final Map<String, String> batchHighWaterMarks;

  /// Populated when the upload failed.
  final Object? error;

  List<String> get filenames => batchHighWaterMarks.keys.toList(growable: false);

  factory UploadResult.success({
    required Map<String, String> batchHighWaterMarks,
  }) {
    return UploadResult._(
      isSuccess: true,
      batchHighWaterMarks: Map<String, String>.from(batchHighWaterMarks),
    );
  }

  factory UploadResult.failure({
    required Object error,
    List<String> failedFilenames = const [],
  }) {
    final map = <String, String>{
      for (final filename in failedFilenames) filename: '',
    };
    return UploadResult._(
      isSuccess: false,
      batchHighWaterMarks: map,
      error: error,
    );
  }
}
