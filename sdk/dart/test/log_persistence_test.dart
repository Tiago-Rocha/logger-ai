import 'dart:convert';

import 'package:file/memory.dart';
import 'package:logger_sdk/logger_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('FileLogPersistence', () {
    late MemoryFileSystem fileSystem;
    late TestJsonSerializer serializer;
    late LogPersistenceConfig config;
    late FileLogPersistence persistence;

    setUp(() {
      fileSystem = MemoryFileSystem();
      serializer = TestJsonSerializer();
      config = const LogPersistenceConfig(
        rootDirectory: '/logs',
        metadataFileName: 'state.json',
        filePrefix: 'batch_',
        fileExtension: '.jsonl',
        maxRecordsPerFile: 2,
        maxBytesPerFile: 1024,
      );
      persistence = FileLogPersistence(
        fileSystem: fileSystem,
        serializer: serializer,
        config: config,
      );
    });

    test('initialize prepares storage directory and metadata file', () async {
      await persistence.initialize();

      expect(fileSystem.directory('/logs').existsSync(), isTrue);
      expect(fileSystem.file('/logs/state.json').existsSync(), isTrue);
    });

    test('append stores NDJSON entries and rotates files by record count',
        () async {
      await persistence.initialize();
      final first = fakeEvent('01AA');
      final second = fakeEvent('01AB');
      final third = fakeEvent('01AC');

      await persistence.append(first);
      await persistence.append(second);
      await persistence.append(third);

      final firstFile = fileSystem.file('/logs/batch_001.jsonl');
      final secondFile = fileSystem.file('/logs/batch_002.jsonl');

      expect(firstFile.existsSync(), isTrue);
      expect(
        firstFile.readAsStringSync(),
        '${serializer.encode(first)}\n${serializer.encode(second)}\n',
      );

      expect(secondFile.existsSync(), isTrue);
      expect(
        secondFile.readAsStringSync(),
        '${serializer.encode(third)}\n',
      );
    });

    test('markBatchUploaded removes batch and records high-water mark',
        () async {
      await persistence.initialize();
      final first = fakeEvent('HW1');
      final second = fakeEvent('HW2');
      final third = fakeEvent('HW3');
      await persistence.append(first);
      await persistence.append(second);
      await persistence.append(third);

      final batches = await persistence.pendingBatches();
      expect(batches, isNotEmpty);

      await persistence.markBatchUploaded(
        batches.first.filename,
        highWaterMark: second.recordId,
      );

      expect(fileSystem.file('/logs/batch_001.jsonl').existsSync(), isFalse);
      expect(fileSystem.file('/logs/batch_002.jsonl').existsSync(), isTrue);

      final state = await persistence.loadState();
      expect(state.lastUploadedRecordId, second.recordId);
      expect(state.activeBatchFile, 'batch_002.jsonl');
    });
  });
}

class TestJsonSerializer extends JsonSerializer {
  @override
  String encode(LogEvent event) {
    return jsonEncode(<String, Object?>{
      'id': event.recordId,
      'payload': event.payload,
    });
  }
}

LogEvent fakeEvent(String recordId) {
  return LogEvent(
    recordId: recordId,
    payload: const {'message': 'test'},
  );
}
