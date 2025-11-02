import 'dart:async';

import 'package:logger_sdk/logger_sdk.dart';

Future<void> main() async {
  final client = ConsoleLoggerClient();
  await client.start();
}

class ConsoleLoggerClient {
  ConsoleLoggerClient() {
    _scheduler = _ConsoleScheduler();
    _uploadManager = _ConsoleUploadManager();
    _sdk = LoggerSdk(
      scheduler: _scheduler,
      uploadManager: _uploadManager,
    );
  }

  late final LoggerSdk _sdk;
  late final _ConsoleScheduler _scheduler;
  late final _ConsoleUploadManager _uploadManager;

  Future<void> start() async {
    print('Configuring Logger SDK for periodic uploads every 15 minutes...');
    final schedule =
        UploadSchedule.periodic(frequency: const Duration(minutes: 15));
    _sdk.configureScheduling(schedule);

    print('Simulating two background runs.');
    await _scheduler.trigger();
    await _scheduler.trigger();

    print('Upload attempts recorded: ${_uploadManager.invocationCount}');
  }
}

class _ConsoleScheduler implements BackgroundScheduler {
  _ConsoleScheduler();
  UploadSchedule? registeredSchedule;

  int fireCount = 0;

  @override
  void register({
    required UploadSchedule schedule,
    required ScheduledUploadTask task,
  }) {
    registeredSchedule = schedule;
    _task = task;
    print('Background work registered: every \\${schedule.frequency}');
  }

  ScheduledUploadTask? _task;

  Future<void> trigger() async {
    fireCount += 1;
    print('Background trigger #$fireCount');
    await _task?.call();
  }
}

class _ConsoleUploadManager implements UploadManager {
  int invocationCount = 0;

  @override
  Future<UploadResult> runScheduledUpload() async {
    invocationCount += 1;
    print('UploadManager invoked (count=$invocationCount)');
    return const UploadResult.success();
  }
}
