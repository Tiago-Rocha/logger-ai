/// Coordinates the preparation and dispatch of log batches to the backend.
abstract class UploadManager {
  /// Performs a scheduled upload attempt and returns the resulting outcome.
  Future<UploadResult> runScheduledUpload();
}

/// Outcome returned from an upload attempt.
class UploadResult {
  const UploadResult._(this.isSuccess, [this.error]);

  /// Indicates whether the upload completed successfully.
  final bool isSuccess;

  /// Populated when the upload failed.
  final Object? error;

  const UploadResult.success() : this._(true);

  const UploadResult.failure(Object error) : this._(false, error);
}
