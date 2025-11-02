import '../scheduling/background_scheduler.dart';
import '../scheduling/upload_schedule.dart';
import '../upload/upload_manager.dart';
import '../scheduling/constraint_evaluator.dart';

/// Primary entry point that host applications integrate with.
class LoggerSdk {
  LoggerSdk({
    required BackgroundScheduler scheduler,
    required UploadManager uploadManager,
    UploadConditionEvaluator conditionEvaluator =
        const AllowAllConstraintEvaluator(),
  })  : _scheduler = scheduler,
        _uploadManager = uploadManager,
        _conditionEvaluator = conditionEvaluator;

  final BackgroundScheduler _scheduler;
  final UploadManager _uploadManager;
  final UploadConditionEvaluator _conditionEvaluator;

  UploadSchedule? _currentSchedule;

  /// Registers background work according to the supplied schedule.
  void configureScheduling(UploadSchedule schedule) {
    _currentSchedule = schedule;
    _scheduler.register(
      schedule: schedule,
      task: _runScheduledUpload,
    );
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

    await _uploadManager.runScheduledUpload();
  }
}
