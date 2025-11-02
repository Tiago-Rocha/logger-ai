import 'package:logger_sdk/logger_sdk.dart';
import 'package:test/test.dart';

import 'logger_acceptance_harness.dart';
import 'world.dart';

final List<Scenario> allScenarios = [
  scenario('Uploading follows the scheduled cadence', (steps) {
    steps.given('the host configures a periodic upload policy',
        (context) async {
      final world = obtainWorld(context);
      await world.configureCollector();
      await world.appendEvent('CAD-1', message: 'scheduled');
      world.configureUploadSuccess(
        highWaterMarks: {'batch_001.jsonl': 'CAD-1'},
      );
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
      await world.configureCollector();
      await world.appendEvent('COND-1', message: 'conditional');
      await world.configureConstraints(
        const UploadConstraints(
          wifiOnly: true,
          requiresCharging: true,
        ),
      );
      world.updateDeviceConditions(hasWifi: true, isCharging: true);
      world.configureUploadSuccess(
        highWaterMarks: {'batch_001.jsonl': 'COND-1'},
      );
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
      final world = obtainWorld(context);
      await world.configureCollector();
      await world.appendEvent('BG-1', message: 'background run');
      world.configureUploadSuccess(highWaterMarks: {'batch_001.jsonl': 'BG-1'});
      await world.configurePeriodicUpload(const Duration(minutes: 15));
    });
    steps.when('the app is no longer in the foreground', (context) async {
      final world = obtainWorld(context);
      await world.triggerBackgroundRun();
    });
    steps.then('scheduled uploads still attempt delivery', (context) async {
      final world = obtainWorld(context);
      expect(world.uploadManager.invocationCount, equals(1));
      expect(world.uploadRequests().length, equals(1));
      expect(await world.pendingBatchFilenames(), isEmpty);
      expect(world.delegate.uploadSuccesses.length, equals(1));
    });
  }),
  scenario('Hosts receive delivery outcomes', (steps) {
    steps.given('there is a batch ready to upload', (context) async {
      final world = obtainWorld(context);
      await world.configureCollector();
      await world.appendEvent('UP-S', message: 'success');
      world.configureUploadSuccess(highWaterMarks: {'batch_001.jsonl': 'UP-S'});
      await world.configurePeriodicUpload(const Duration(minutes: 5));
    });
    steps.when('the upload succeeds or fails', (context) async {
      final world = obtainWorld(context);
      await world.triggerBackgroundRun();
      expect(world.delegate.uploadSuccesses.length, equals(1));

      await world.appendEvent('UP-F', message: 'failure');
      world.configureUploadFailure(Exception('network down'));
      await world.triggerBackgroundRun();
    });
    steps.then('the host is notified of the result exactly once',
        (context) async {
      final world = obtainWorld(context);
      expect(world.delegate.uploadSuccesses.length, equals(1));
      expect(world.delegate.uploadFailures.length, equals(1));
    });
  }),
  scenario('Completed batches do not resend', (steps) {
    steps.given('a batch was previously marked delivered', (context) async {
      final world = obtainWorld(context);
      await world.configureCollector();
      await world.appendEvent('DONE-1', message: 'first');
      world.configureUploadSuccess(highWaterMarks: {'batch_001.jsonl': 'DONE-1'});
      await world.configurePeriodicUpload(const Duration(minutes: 10));
      await world.triggerBackgroundRun();
      expect(await world.pendingBatchFilenames(), isEmpty);
    });
    steps.when('the next upload window starts', (context) async {
      final world = obtainWorld(context);
      await world.triggerBackgroundRun();
    });
    steps.then('already acknowledged records are skipped', (context) async {
      final world = obtainWorld(context);
      expect(world.uploadManager.invocationCount, equals(1));
      expect(world.uploadRequests().length, equals(1));
    });
  }),
  scenario('Interrupted uploads recover gracefully', (steps) {
    steps.given('an upload is in progress', (context) async {
      final world = obtainWorld(context);
      await world.configureCollector();
      await world.appendEvent('FAIL-1', message: 'first');
      await world.configurePeriodicUpload(const Duration(minutes: 3));
      world.configureUploadFailure(Exception('timeout'));
    });
    steps.when('the operating system cancels the task', (context) async {
      final world = obtainWorld(context);
      await world.triggerBackgroundRun();
      expect(world.delegate.uploadFailures.length, equals(1));
      world.configureUploadSuccess(highWaterMarks: {'batch_001.jsonl': 'FAIL-1'});
      await world.triggerBackgroundRun();
    });
    steps.then('state is cleaned up and the work is rescheduled',
        (context) async {
      final world = obtainWorld(context);
      expect(await world.pendingBatchFilenames(), isEmpty);
      expect(world.delegate.uploadSuccesses.length, equals(1));
    });
  }),
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
      final entry = entries.single;
      expect(entry['recordId'], 'COL-A1');
      expect(entry['payload'], {'message': 'collected'});
      expect(entry['metadata'], {
        'timestamp': '2025-01-01T00:00:00.000Z',
        'attributes': {'session_id': 'abc'},
      });
    });
  }),
  scenario('Collector populates metadata when omitted', (steps) {
    steps.given('a collector with a deterministic clock', (context) async {
      final world = obtainWorld(context);
      context.write('collectorClock', DateTime.utc(2025, 5, 12, 10));
      await world.configureCollector(
        clockTime: context.read('collectorClock'),
      );
    });
    steps.when('the host records an event without metadata', (context) async {
      final world = obtainWorld(context);
      await world.recordViaCollector(
        recordId: 'COL-A2',
        payload: {'message': 'default metadata'},
        metadata: null,
      );
    });
    steps.then('the SDK stamps the entry with the current clock timestamp',
        (context) async {
      final world = obtainWorld(context);
      final expectedTime =
          context.read<DateTime>('collectorClock').toUtc().toIso8601String();
      final contents = await world.readBatchContents('batch_001.jsonl');
      final entries = world.decodeEntries(contents);
      expect(entries.length, 1);
      final entry = entries.single;
      expect(entry['metadata'], containsPair('timestamp', expectedTime));
    });
  }),
  scenario('Collector snapshots payload state at record time', (steps) {
    steps.given('a collector configured with file persistence',
        (context) async {
      final world = obtainWorld(context);
      await world.configureCollector();
    });
    steps.when('the host mutates the payload after recording', (context) async {
      final world = obtainWorld(context);
      final payload = {'message': 'before'};
      context.write('mutablePayload', payload);
      await world.recordViaCollector(
        recordId: 'COL-A3',
        payload: payload,
        metadata: null,
      );
      payload['message'] = 'after';
    });
    steps.then('the persisted entry retains the original payload snapshot',
        (context) async {
      final world = obtainWorld(context);
      final payload = context.read<Map<String, Object?>>('mutablePayload');
      expect(payload['message'], 'after');

      final contents = await world.readBatchContents('batch_001.jsonl');
      final entries = world.decodeEntries(contents);
      expect(entries.length, 1);
      final entry = entries.single;
      expect(entry['payload'], {'message': 'before'});
    });
  }),
  scenario('Collector normalizes nested payload structures', (steps) {
    steps.given('a collector configured with file persistence',
        (context) async {
      final world = obtainWorld(context);
      await world.configureCollector();
    });
    steps.when('the host supplies nested mutable collections', (context) async {
      final world = obtainWorld(context);
      final payload = <String, Object?>{
        'list': <Object?>[
          1,
          2,
          <String, Object?>{'inner': 'value'},
        ],
        'map': <String, Object?>{
          'nested': <Object?>['a', 'b'],
          'numbers': <Object?>[1, 2, 3],
        },
      };
      context.write('mutablePayload', payload);
      await world.recordViaCollector(
        recordId: 'COL-A5',
        payload: payload,
      );
      final list = payload['list'] as List<Object?>;
      final innerMap = list[2] as Map<String, Object?>;
      innerMap['inner'] = 'mutated';
      final nestedMap = payload['map'] as Map<String, Object?>;
      nestedMap['nested'] = <Object?>[];
    });
    steps.then('the persisted entry retains the original nested values',
        (context) async {
      final world = obtainWorld(context);
      final contents = await world.readBatchContents('batch_001.jsonl');
      final entries = world.decodeEntries(contents);
      final entry = entries.single;
      expect(entry['payload'], {
        'list': [
          1,
          2,
          {'inner': 'value'}
        ],
        'map': {
          'nested': ['a', 'b'],
          'numbers': [1, 2, 3],
        },
      });
    });
  }),
  scenario('Collector enforces required record identifiers', (steps) {
    steps.given('a collector with persistence configured', (context) async {
      final world = obtainWorld(context);
      await world.configureCollector();
    });
    steps.when('the host attempts to record with an empty identifier',
        (context) async {
      final world = obtainWorld(context);
      await world.attemptCollectorRecord(
        recordId: '',
        payload: {'message': 'invalid'},
      );
    });
    steps.then('the SDK rejects the record without persisting it',
        (context) async {
      final world = obtainWorld(context);
      expect(world.lastCollectorError, isA<ArgumentError>());
      final contents = await world.readBatchContents('batch_001.jsonl');
      expect(contents.trim(), isEmpty);
      expect(world.delegate.rejectedErrors.length, 1);
      expect(world.delegate.recordedEvents, isEmpty);
    });
  }),
  scenario('Collector notifies delegate on successful record', (steps) {
    steps.given('a collector configured with a delegate', (context) async {
      final world = obtainWorld(context);
      await world.configureCollector();
    });
    steps.when('an event is recorded successfully', (context) async {
      final world = obtainWorld(context);
      await world.recordViaCollector(
        recordId: 'COL-A4',
        payload: {'message': 'delegate'},
      );
    });
    steps.then('the delegate receives the recorded event', (context) async {
      final world = obtainWorld(context);
      expect(world.delegate.recordedEvents.length, 1);
      final event = world.delegate.recordedEvents.single;
      expect(event.recordId, 'COL-A4');
      expect(event.payload, {'message': 'delegate'});
    });
  }),
  scenario('Batch manager enforces per-run batch limits', (steps) {
    steps.given('existing batches exceed the policy limit', (context) async {
      final world = obtainWorld(context);
      await world.configurePersistence(
        maxRecordsPerFile: 1,
        maxBytesPerFile: 1024,
      );
      await world.appendEvent('BATCH-1', message: 'first');
      await world.appendEvent('BATCH-2', message: 'second');
      await world.appendEvent('BATCH-3', message: 'third');
      world.configureBatchManager(maxBatchesPerCycle: 2);
    });
    steps.when('the batch manager prepares the next upload cycle',
        (context) async {
      final world = obtainWorld(context);
      final batches = await world.nextBatches();
      context.write('selectedBatches', batches);
    });
    steps.then('only the allowed number of batches are returned',
        (context) async {
      final batches =
          context.read<List<PendingBatch>>('selectedBatches');
      expect(batches.length, 2);
      expect(batches.map((b) => b.filename), containsAll(['batch_001.jsonl', 'batch_002.jsonl']));
    });
  }),
];
