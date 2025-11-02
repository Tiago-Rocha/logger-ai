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
  late final FakeBackgroundScheduler scheduler;
  late final FakeUploadManager uploadManager;
  late final FakeConditionEvaluator conditionEvaluator;
  late final LoggerSdk sdk;

  Duration? _configuredFrequency;
  UploadConstraints? _configuredConstraints;
  int deferredRuns = 0;

  void configurePeriodicUpload(Duration frequency) {
    _bootstrap();
    _configuredFrequency = frequency;
    sdk.configureScheduling(
      UploadSchedule.periodic(frequency: frequency),
    );
  }

  void configureConstraints(UploadConstraints constraints) {
    _bootstrap();
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

  Duration? get configuredFrequency => _configuredFrequency;
  UploadConstraints? get configuredConstraints => _configuredConstraints;

  void _bootstrap() {
    scheduler = FakeBackgroundScheduler();
    uploadManager = FakeUploadManager();
    conditionEvaluator = FakeConditionEvaluator(
      onDenied: () => deferredRuns += 1,
    );
    sdk = LoggerSdk(
      scheduler: scheduler,
      uploadManager: uploadManager,
      conditionEvaluator: conditionEvaluator,
    );
  }
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
  int denials = 0;

  @override
  bool canRun(UploadConstraints constraints) {
    evaluations += 1;
    final canRun = (!constraints.wifiOnly || hasWifi) &&
        (!constraints.requiresCharging || isCharging);
    if (!canRun) {
      denials += 1;
      onDenied();
    }
    return canRun;
  }
}

typedef VoidCallback = void Function();
