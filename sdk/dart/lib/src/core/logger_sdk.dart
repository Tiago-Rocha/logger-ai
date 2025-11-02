import '../batch/batch_manager.dart';
import '../hooks/logger_delegate.dart';
import '../persistence/log_persistence.dart';
import '../scheduling/background_scheduler.dart';
import '../scheduling/constraint_evaluator.dart';
import '../scheduling/upload_schedule.dart';
import '../upload/upload_manager.dart';

/// Primary entry point that host applications integrate with.
class LoggerSdk {
  LoggerSdk({
    required BackgroundScheduler scheduler,
    required UploadManager uploadManager,
    UploadConditionEvaluator conditionEvaluator =
        const AllowAllConstraintEvaluator(),
    LoggerDelegate? delegate,
  })  : _scheduler = scheduler,
        _uploadManager = uploadManager,
        _conditionEvaluator = conditionEvaluator,
        _delegate = delegate;

  final BackgroundScheduler _scheduler;
  final UploadManager _uploadManager;
  final UploadConditionEvaluator _conditionEvaluator;
  BatchManager? _batchManager;
  FileLogPersistence? _persistence;
  LoggerDelegate? _delegate;

  UploadSchedule? _currentSchedule;

  /// Registers background work according to the supplied schedule.
  void configureScheduling(UploadSchedule schedule) {
    _currentSchedule = schedule;
    _scheduler.register(
      schedule: schedule,
      task: _runScheduledUpload,
    );
  }

  Future<void> cancelScheduling() async {
    await _scheduler.cancel();
    _currentSchedule = null;
  }

  void configureIntake({
    BatchManager? batchManager,
    FileLogPersistence? persistence,
    LoggerDelegate? delegate,
  }) {
    _batchManager = batchManager ?? _batchManager;
    _persistence = persistence ?? _persistence;
    _delegate = delegate ?? _delegate;
  }

  /// Returns the last schedule provided by the host.
  UploadSchedule? get currentSchedule => _currentSchedule;

  Future<void> _runScheduledUpload() async {
    final schedule = _currentSchedule;
    if (schedule == null) {
      return;
    }

    final constraints = schedule.constraints;
    if (!_conditionEvaluator.canRun(constraints)) {
      return;
    }

    final batches = await _batchManager?.nextBatches() ?? const [];
    if (batches.isEmpty) {
      return;
    }

    final result = await _uploadManager.upload(batches);

    if (!result.isSuccess) {
      final filenames = result.filenames;
      if (filenames.isNotEmpty) {
        _delegate?.onUploadFailure(
            filenames, result.error ?? Exception('upload failed'));
      }
      return;
    }

    final persistence = _persistence;
    if (persistence == null) {
      return;
    }

    for (final entry in result.batchHighWaterMarks.entries) {
      final filename = entry.key;
      final highWaterMark = entry.value.isEmpty ? null : entry.value;
      await persistence.markBatchUploaded(
        filename,
        highWaterMark: highWaterMark,
      );
    }

    _delegate?.onUploadSuccess(result.filenames);
  }
}
