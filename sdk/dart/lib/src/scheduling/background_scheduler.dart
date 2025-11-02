import 'upload_schedule.dart';

/// Function invoked when scheduled work should execute.
typedef ScheduledUploadTask = Future<void> Function();

/// Platform-specific bridge that registers background work with the host OS.
abstract class BackgroundScheduler {
  void register({
    required UploadSchedule schedule,
    required ScheduledUploadTask task,
  });
}
