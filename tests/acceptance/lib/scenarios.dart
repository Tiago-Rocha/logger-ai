import 'package:logger_sdk/logger_sdk.dart';
import 'package:test/test.dart';

import 'logger_acceptance_harness.dart';
import 'world.dart';

final List<Scenario> allScenarios = [
  scenario('Uploading follows the scheduled cadence', (steps) {
    steps.given('the host configures a periodic upload policy',
        (context) async {
      final world = obtainWorld(context);
      await world.configurePeriodicUpload(const Duration(minutes: 15));
    });
    steps.when('the scheduler triggers a background run', (context) async {
      final world = obtainWorld(context);
      await world.triggerBackgroundRun();
    });
    steps.then(
        'logs are prepared for delivery according to the configured frequency',
        (context) async {
      final world = obtainWorld(context);
      final registered = world.scheduler.registeredSchedule;
      expect(registered, isNotNull, reason: 'schedule should be registered');
      expect(
        registered!.frequency,
        equals(world.configuredFrequency),
        reason: 'scheduler should honour requested frequency',
      );
      expect(
        world.scheduler.fireCount,
        equals(1),
        reason: 'run should execute once per trigger',
      );
      expect(
        world.uploadManager.invocationCount,
        equals(1),
        reason: 'upload manager should prepare the batch for delivery',
      );
    });
  }),
  scenario('Uploads honour connectivity and power preferences', (steps) {
    steps.given('the host requests uploads only on wi-fi while charging',
        (context) async {
      final world = obtainWorld(context);
      await world.configureConstraints(
        const UploadConstraints(
          wifiOnly: true,
          requiresCharging: true,
        ),
      );
      world.updateDeviceConditions(hasWifi: true, isCharging: true);
    });
    steps.when('the device does not meet the requested conditions',
        (context) async {
      final world = obtainWorld(context);
      world.updateDeviceConditions(hasWifi: false, isCharging: false);
      await world.triggerBackgroundRun();
    });
    steps.then('the upload is deferred without losing pending work',
        (context) async {
      final world = obtainWorld(context);
      expect(world.scheduler.fireCount, equals(1),
          reason: 'background run should still fire');
      expect(world.uploadManager.invocationCount, equals(0),
          reason: 'upload should not start');
      expect(world.deferredRuns, equals(1),
          reason: 'run should be counted as deferred');
      expect(world.configuredConstraints?.wifiOnly, isTrue);
      expect(world.configuredConstraints?.requiresCharging, isTrue);
    });
  }),
  scenario('Background processing continues outside the foreground session',
      (steps) {
    steps.given('background work has been registered', (context) async {
      throw const PendingStep();
    });
    steps.when('the app is no longer in the foreground', (context) async {
      throw const PendingStep();
    });
    steps.then('scheduled uploads still attempt delivery', (context) async {
      throw const PendingStep();
    });
  }, enabled: false),
  scenario('Hosts receive delivery outcomes', (steps) {
    steps.given('there is a batch ready to upload', (context) async {
      throw const PendingStep();
    });
    steps.when('the upload succeeds or fails', (context) async {
      throw const PendingStep();
    });
    steps.then('the host is notified of the result exactly once',
        (context) async {
      throw const PendingStep();
    });
  }, enabled: false),
  scenario('Completed batches do not resend', (steps) {
    steps.given('a batch was previously marked delivered', (context) async {
      throw const PendingStep();
    });
    steps.when('the next upload window starts', (context) async {
      throw const PendingStep();
    });
    steps.then('already acknowledged records are skipped', (context) async {
      throw const PendingStep();
    });
  }, enabled: false),
  scenario('Interrupted uploads recover gracefully', (steps) {
    steps.given('an upload is in progress', (context) async {
      throw const PendingStep();
    });
    steps.when('the operating system cancels the task', (context) async {
      throw const PendingStep();
    });
    steps.then('state is cleaned up and the work is rescheduled',
        (context) async {
      throw const PendingStep();
    });
  }, enabled: false),
  scenario('Persistence rotates batches when record limits are reached',
      (steps) {
    steps.given('file persistence rotates after two records', (context) async {
      final world = obtainWorld(context);
      await world.configurePersistence(
        maxRecordsPerFile: 2,
        maxBytesPerFile: 1024,
      );
    });
    steps.when('three log events are recorded', (context) async {
      final world = obtainWorld(context);
      final encoded = <String>[];
      encoded.add(await world.appendEvent('01AA', message: 'first'));
      encoded.add(await world.appendEvent('01AB', message: 'second'));
      encoded.add(await world.appendEvent('01AC', message: 'third'));
      context.write('encodedLines', encoded);
    });
    steps.then('two NDJSON files contain the stored records in order',
        (context) async {
      final world = obtainWorld(context);
      final encoded = context.read<List<String>>('encodedLines');
      final firstFile = await world.readBatchContents('batch_001.jsonl');
      final secondFile = await world.readBatchContents('batch_002.jsonl');

      expect(
        firstFile,
        '${encoded[0]}\n${encoded[1]}\n',
        reason: 'first batch should contain the first two records',
      );
      expect(
        secondFile,
        '${encoded[2]}\n',
        reason: 'second batch should contain the third record',
      );

      final state = await world.loadPersistenceState();
      expect(state.activeBatchFile, 'batch_002.jsonl');
    });
  }),
  scenario('Uploaded batches advance the high-water mark', (steps) {
    steps.given('a persisted queue with multiple batches', (context) async {
      final world = obtainWorld(context);
      await world.configurePersistence(
        maxRecordsPerFile: 2,
        maxBytesPerFile: 1024,
      );
      await world.appendEvent('HW1', message: 'first');
      await world.appendEvent('HW2', message: 'second');
      await world.appendEvent('HW3', message: 'third');
      final batches = await world.pendingBatches();
      context.write('pendingBatches', batches);
    });
    steps.when('the oldest batch is marked uploaded with record HW2',
        (context) async {
      final world = obtainWorld(context);
      final batches = context.read<List<PendingBatch>>('pendingBatches');
      final oldest = batches.first;
      await world.markBatchUploaded(
        oldest.filename,
        highWaterMark: 'HW2',
      );
    });
    steps.then('state reflects the high-water mark and remaining batch',
        (context) async {
      final world = obtainWorld(context);
      final state = await world.loadPersistenceState();
      expect(state.lastUploadedRecordId, 'HW2');
      expect(state.activeBatchFile, 'batch_002.jsonl');

      expect(world.batchFileExists('batch_001.jsonl'), isFalse);
      expect(world.batchFileExists('batch_002.jsonl'), isTrue);

      final remaining = await world.pendingBatches();
      expect(remaining.length, 1);
      expect(remaining.first.filename, 'batch_002.jsonl');
    });
  }),
  scenario('Collector records events with metadata into persistence', (steps) {
    steps.given('a collector configured with file persistence',
        (context) async {
      final world = obtainWorld(context);
      await world.configureCollector();
    });
    steps.when('the host records an event with metadata', (context) async {
      final world = obtainWorld(context);
      await world.recordViaCollector(
        recordId: 'COL-A1',
        payload: {'message': 'collected'},
        metadata: LogMetadata(
          timestamp: DateTime.parse('2025-01-01T00:00:00Z'),
          attributes: const {'session_id': 'abc'},
        ),
      );
    });
    steps.then('the persisted entry keeps record, payload, and metadata',
        (context) async {
      final world = obtainWorld(context);
      final contents = await world.readBatchContents('batch_001.jsonl');
      final entries = world.decodeEntries(contents);
      expect(entries.length, 1);
      final entry = entries.single as Map<String, Object?>;
      expect(entry['recordId'], 'COL-A1');
      expect(entry['payload'], {'message': 'collected'});
      expect(entry['metadata'], {
        'timestamp': '2025-01-01T00:00:00.000Z',
        'attributes': {'session_id': 'abc'},
      });
    });
  }),
];
