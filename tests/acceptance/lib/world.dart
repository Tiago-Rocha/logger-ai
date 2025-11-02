import 'dart:convert';

import 'package:file/memory.dart';
import 'package:logger_sdk/logger_sdk.dart';

import 'logger_acceptance_harness.dart';

const _worldKey = 'world';

TestWorld obtainWorld(StepContext context) {
  final existing = context.maybeRead<TestWorld>(_worldKey);
  if (existing != null) {
    return existing;
  }
  final created = TestWorld();
  context.write(_worldKey, created);
  return created;
}

class TestWorld {
  FakeBackgroundScheduler get scheduler => _scheduler!;
  FakeUploadManager get uploadManager => _uploadManager!;
  FakeConditionEvaluator get conditionEvaluator => _conditionEvaluator!;
  LoggerSdk get sdk => _sdk!;
  LogCollector get collector => _collector!;

  FileLogPersistence get persistence => _persistence!;
  MemoryFileSystem get fileSystem => _fileSystem!;
  LogPersistenceConfig get persistenceConfig => _persistenceConfig!;

  Duration? get configuredFrequency => _configuredFrequency;
  UploadConstraints? get configuredConstraints => _configuredConstraints;

  int deferredRuns = 0;

  Future<void> configurePeriodicUpload(Duration frequency) async {
    _ensureSchedulingBootstrap();
    _configuredFrequency = frequency;
    sdk.configureScheduling(
      UploadSchedule.periodic(frequency: frequency),
    );
  }

  Future<void> configureConstraints(UploadConstraints constraints) async {
    _ensureSchedulingBootstrap();
    _configuredFrequency = const Duration(minutes: 15);
    _configuredConstraints = constraints;
    sdk.configureScheduling(
      UploadSchedule.periodic(
        frequency: _configuredFrequency!,
        constraints: constraints,
      ),
    );
  }

  void updateDeviceConditions({
    required bool hasWifi,
    required bool isCharging,
  }) {
    conditionEvaluator
      ..hasWifi = hasWifi
      ..isCharging = isCharging;
  }

  Future<void> triggerBackgroundRun() async {
    await scheduler.fire();
  }

  Future<void> configurePersistence({
    required int maxRecordsPerFile,
    required int maxBytesPerFile,
  }) async {
    _fileSystem = MemoryFileSystem();
    _serializer = HarnessJsonSerializer();
    _persistenceConfig = LogPersistenceConfig(
      rootDirectory: '/logs',
      metadataFileName: 'state.json',
      filePrefix: 'batch_',
      fileExtension: '.jsonl',
      maxRecordsPerFile: maxRecordsPerFile,
      maxBytesPerFile: maxBytesPerFile,
    );
    _persistence = FileLogPersistence(
      fileSystem: _fileSystem!,
      serializer: _serializer!,
      config: _persistenceConfig!,
    );
    await _persistence!.initialize();
  }

  Future<void> configureCollector() async {
    await configurePersistence(
      maxRecordsPerFile: 10,
      maxBytesPerFile: 1024 * 1024,
    );
    _collector = LogCollector(persistence: _persistence!);
  }

  Future<String> appendEvent(String recordId, {required String message}) async {
    final event = LogEvent(
      recordId: recordId,
      payload: {'message': message},
    );
    await persistence.append(event);
    return _serializer!.encode(event);
  }

  Future<String> readBatchContents(String filename) async {
    final file =
        fileSystem.file('${persistenceConfig.rootDirectory}/$filename');
    if (!await file.exists()) {
      return '';
    }
    return file.readAsString();
  }

  bool batchFileExists(String filename) {
    final file =
        fileSystem.file('${persistenceConfig.rootDirectory}/$filename');
    return file.existsSync();
  }

  Future<List<PendingBatch>> pendingBatches() async {
    return persistence.pendingBatches();
  }

  Future<void> recordViaCollector({
    required String recordId,
    required Map<String, Object?> payload,
    LogMetadata? metadata,
  }) async {
    await collector.record(
      recordId: recordId,
      payload: payload,
      metadata: metadata,
    );
  }

  Future<void> markBatchUploaded(
    String filename, {
    required String highWaterMark,
  }) async {
    await persistence.markBatchUploaded(
      filename,
      highWaterMark: highWaterMark,
    );
  }

  Future<LogPersistenceState> loadPersistenceState() async {
    return persistence.loadState();
  }

  List<Map<String, Object?>> decodeEntries(String contents) {
    return const LineSplitter()
        .convert(contents)
        .where((line) => line.isNotEmpty)
        .map((line) => jsonDecode(line) as Map<String, Object?>)
        .toList();
  }

  void _ensureSchedulingBootstrap() {
    deferredRuns = 0;
    _scheduler = FakeBackgroundScheduler();
    _uploadManager = FakeUploadManager();
    _conditionEvaluator = FakeConditionEvaluator(
      onDenied: () => deferredRuns += 1,
    );
    _sdk = LoggerSdk(
      scheduler: _scheduler!,
      uploadManager: _uploadManager!,
      conditionEvaluator: _conditionEvaluator!,
    );
  }

  FakeBackgroundScheduler? _scheduler;
  FakeUploadManager? _uploadManager;
  FakeConditionEvaluator? _conditionEvaluator;
  LoggerSdk? _sdk;

  MemoryFileSystem? _fileSystem;
  HarnessJsonSerializer? _serializer;
  FileLogPersistence? _persistence;
  LogPersistenceConfig? _persistenceConfig;
  LogCollector? _collector;

  Duration? _configuredFrequency;
  UploadConstraints? _configuredConstraints;
}

class FakeBackgroundScheduler implements BackgroundScheduler {
  UploadSchedule? registeredSchedule;
  ScheduledUploadTask? registeredTask;
  int fireCount = 0;

  @override
  void register({
    required UploadSchedule schedule,
    required ScheduledUploadTask task,
  }) {
    registeredSchedule = schedule;
    registeredTask = task;
  }

  Future<void> fire() async {
    final task = registeredTask;
    if (task == null) {
      throw StateError('No task registered.');
    }
    fireCount += 1;
    await task();
  }
}

class FakeUploadManager implements UploadManager {
  int invocationCount = 0;

  @override
  Future<UploadResult> runScheduledUpload() async {
    invocationCount += 1;
    return const UploadResult.success();
  }
}

class FakeConditionEvaluator implements UploadConditionEvaluator {
  FakeConditionEvaluator({required this.onDenied});

  final VoidCallback onDenied;
  bool hasWifi = true;
  bool isCharging = true;
  int evaluations = 0;

  @override
  bool canRun(UploadConstraints constraints) {
    evaluations += 1;
    final meetsWifi = !constraints.wifiOnly || hasWifi;
    final meetsCharging = !constraints.requiresCharging || isCharging;
    final allowed = meetsWifi && meetsCharging;
    if (!allowed) {
      onDenied();
    }
    return allowed;
  }
}

class HarnessJsonSerializer extends JsonSerializer {
  @override
  String encode(LogEvent event) {
    final map = <String, Object?>{
      'recordId': event.recordId,
      'payload': event.payload,
    };
    final metadata = event.metadata;
    if (metadata != null) {
      map['metadata'] = metadata.toJson();
    }
    return jsonEncode(map);
  }
}

typedef VoidCallback = void Function();
