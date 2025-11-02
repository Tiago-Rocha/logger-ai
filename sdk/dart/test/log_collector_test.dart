import 'dart:convert';

import 'package:file/memory.dart';
import 'package:logger_sdk/logger_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('LogCollector', () {
    late MemoryFileSystem fileSystem;
    late FileLogPersistence persistence;
    late JsonSerializer serializer;

    setUp(() async {
      fileSystem = MemoryFileSystem();
      serializer = _TestJsonSerializer();
      persistence = FileLogPersistence(
        fileSystem: fileSystem,
        serializer: serializer,
        config: const LogPersistenceConfig(
          rootDirectory: '/logs',
          metadataFileName: 'state.json',
          filePrefix: 'batch_',
          fileExtension: '.jsonl',
          maxRecordsPerFile: 10,
          maxBytesPerFile: 1024,
        ),
      );
      await persistence.initialize();
    });

    test('records events to persistence with metadata', () async {
      final collector = LogCollector(
        persistence: persistence,
        clock: () => DateTime.utc(2025, 1, 1, 12, 0),
      );

      await collector.record(
        recordId: 'REC-1',
        payload: {'message': 'hello'},
      );

      final batches = await persistence.pendingBatches();
      expect(batches.length, 1);
      final file = fileSystem.file('/logs/batch_001.jsonl');
      final contents = await file.readAsString();
      final lines =
          contents.split('\n').where((line) => line.isNotEmpty).toList();
      expect(lines.length, 1);
      final entry = jsonDecode(lines.first) as Map<String, Object?>;
      expect(entry['recordId'], 'REC-1');
      expect(entry['payload'], {'message': 'hello'});
      expect(entry['metadata'], {
        'timestamp': '2025-01-01T12:00:00.000Z',
        'attributes': <String, Object?>{},
      });
    });

    test('throws and notifies delegate when recordId is empty', () async {
      final delegate = _RecordingDelegate();
      final collector = LogCollector(
        persistence: persistence,
        delegate: delegate,
      );

      expect(
        () => collector.record(recordId: '', payload: {'message': 'bad'}),
        throwsArgumentError,
      );
      expect(delegate.rejectedErrors, isNotEmpty);
      expect(delegate.recordedEvents, isEmpty);
    });
  });
}

class _RecordingDelegate extends LoggerDelegate {
  final List<LogEvent> recordedEvents = [];
  final List<Object> rejectedErrors = [];

  @override
  void onEventRecorded(LogEvent event) {
    recordedEvents.add(event);
  }

  @override
  void onEventRejected(String recordId, Object error) {
    rejectedErrors.add(error);
  }
}

class _TestJsonSerializer extends JsonSerializer {
  @override
  String encode(LogEvent event) {
    return jsonEncode({
      'recordId': event.recordId,
      'payload': event.payload,
      if (event.metadata != null) 'metadata': event.metadata!.toJson(),
    });
  }
}
