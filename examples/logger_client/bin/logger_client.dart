import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:logger_sdk/logger_sdk.dart';

Future<void> main() async {
  final client = ConsoleLoggerClient();
  await client.start();
}

class ConsoleLoggerClient {
  ConsoleLoggerClient()
      : _fileSystem = const LocalFileSystem(),
        _scheduler = _ConsoleScheduler(),
        _delegate = ConsoleLoggerDelegate() {
    _logsRoot = _fileSystem.systemTempDirectory
        .childDirectory('logger_client_logs')
      ..createSync(recursive: true);
    _persistence = FileLogPersistence(
      fileSystem: _fileSystem,
      serializer: _SampleJsonSerializer(),
      config: LogPersistenceConfig(
        rootDirectory: _logsRoot.path,
        metadataFileName: 'state.json',
        filePrefix: 'batch_',
        fileExtension: '.jsonl',
        maxRecordsPerFile: 10,
        maxBytesPerFile: 1024 * 1024,
      ),
    );
    _batchManager = BatchManager(
      persistence: _persistence,
      policy: const LogUploadPolicy(maxBatchesPerCycle: 5),
    );
    _uploadManager = _ConsoleUploadManager(_delegate);
    _collector = LogCollector(
      persistence: _persistence,
      delegate: _delegate,
    );
    _sdk = LoggerSdk(
      scheduler: _scheduler,
      uploadManager: _uploadManager,
      delegate: _delegate,
    )..configureIntake(
        batchManager: _batchManager,
        persistence: _persistence,
        delegate: _delegate,
      );
  }

  final FileSystem _fileSystem;
  final _ConsoleScheduler _scheduler;
  late final Directory _logsRoot;
  late final FileLogPersistence _persistence;
  late final BatchManager _batchManager;
  late final _ConsoleUploadManager _uploadManager;
  late final ConsoleLoggerDelegate _delegate;
  late final LogCollector _collector;
  late final LoggerSdk _sdk;

  Future<void> start() async {
    print('Logger logs root: ${_logsRoot.path}');

    // Record a handful of events.
    await _collector.record(
      recordId: 'WELCOME-1',
      payload: {'message': 'hello from the console client'},
    );
    await _collector.record(
      recordId: 'WELCOME-2',
      payload: {'message': 'background uploads are enabled'},
    );

    // Schedule periodic uploads.
    final schedule = UploadSchedule.periodic(
      frequency: const Duration(minutes: 15),
      constraints: const UploadConstraints(
        wifiOnly: true,
        requiresCharging: false,
      ),
    );
    _sdk.configureScheduling(schedule);
    print('Background work registered. Triggering two runs...');

    await _scheduler.trigger();
    await _scheduler.trigger();

    print('Upload attempts recorded: ${_uploadManager.invocationCount}');
    print('Delegate upload successes: ${_delegate.uploadSuccesses.length}');

    // Demonstrate cancellation of background work.
    print('Cancelling scheduled uploads...');
    await _sdk.cancelScheduling();
    await _scheduler.trigger();
    print('Upload attempts after cancellation: '
        '${_uploadManager.invocationCount}');
  }
}

class _ConsoleScheduler implements BackgroundScheduler {
  ScheduledUploadTask? _task;

  @override
  void register({
    required UploadSchedule schedule,
    required ScheduledUploadTask task,
  }) {
    _task = task;
    print('Background work registered: every ${schedule.frequency}');
  }

  @override
  Future<void> cancel() async {
    _task = null;
    print('Background work cancelled');
  }

  Future<void> trigger() async {
    final task = _task;
    if (task == null) {
      print('No scheduled work to run.');
      return;
    }
    await task();
  }
}

class _ConsoleUploadManager implements UploadManager {
  _ConsoleUploadManager(this._delegate);

  final ConsoleLoggerDelegate _delegate;
  int invocationCount = 0;

  @override
  Future<UploadResult> upload(List<PendingBatch> batches) async {
    invocationCount += 1;
    print('UploadManager invoked (count=$invocationCount)');
    for (final batch in batches) {
      print('  • uploading ${batch.filename} '
          '(records=${batch.recordCount}, bytes=${batch.sizeBytes})');
    }
    // Simulate success and return high-water marks for each batch.
    final marks = <String, String>{
      for (final batch in batches) batch.filename: 'HW-${batch.oldestRecordId}',
    };
    return UploadResult.success(batchHighWaterMarks: marks);
  }
}

class ConsoleLoggerDelegate extends LoggerDelegate {
  final List<LogEvent> recordedEvents = [];
  final List<Object> rejectedEvents = [];
  final List<List<String>> uploadSuccesses = [];
  final List<Object> uploadFailures = [];

  @override
  void onEventRecorded(LogEvent event) {
    recordedEvents.add(event);
    print('Delegate onEventRecorded → ${event.recordId}');
  }

  @override
  void onEventRejected(String recordId, Object error) {
    rejectedEvents.add(error);
    print('Delegate onEventRejected → $recordId ($error)');
  }

  @override
  void onUploadSuccess(List<String> batchFilenames) {
    uploadSuccesses.add(batchFilenames);
    print('Delegate onUploadSuccess → ${batchFilenames.join(', ')}');
  }

  @override
  void onUploadFailure(List<String> batchFilenames, Object error) {
    uploadFailures.add(error);
    print('Delegate onUploadFailure → ${batchFilenames.join(', ')}: $error');
  }
}

class _SampleJsonSerializer extends JsonSerializer {
  @override
  String encode(LogEvent event) {
    return jsonEncode({
      'recordId': event.recordId,
      'payload': event.payload,
      if (event.metadata != null) 'metadata': event.metadata!.toJson(),
    });
  }
}
