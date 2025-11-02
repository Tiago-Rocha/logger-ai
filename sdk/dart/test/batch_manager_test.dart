import 'package:file/memory.dart';
import 'package:logger_sdk/logger_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('BatchManager', () {
    late MemoryFileSystem fileSystem;
    late FileLogPersistence persistence;

    setUp(() async {
      fileSystem = MemoryFileSystem();
      persistence = FileLogPersistence(
        fileSystem: fileSystem,
        serializer: _TestJsonSerializer(),
        config: const LogPersistenceConfig(
          rootDirectory: '/logs',
          metadataFileName: 'state.json',
          filePrefix: 'batch_',
          fileExtension: '.jsonl',
          maxRecordsPerFile: 1,
          maxBytesPerFile: 1024,
        ),
      );
      await persistence.initialize();
      await persistence.append(_fakeEvent('A'));
      await persistence.append(_fakeEvent('B'));
      await persistence.append(_fakeEvent('C'));
    });

    test('nextBatches limits results based on policy', () async {
      final manager = BatchManager(
        persistence: persistence,
        policy: const LogUploadPolicy(maxBatchesPerCycle: 2),
      );

      final batches = await manager.nextBatches();
      expect(batches.length, 2);
      expect(batches.map((b) => b.filename), containsAll(['batch_001.jsonl', 'batch_002.jsonl']));
    });

    test('nextBatches returns all when policy allows', () async {
      final manager = BatchManager(
        persistence: persistence,
        policy: const LogUploadPolicy(maxBatchesPerCycle: null),
      );

      final batches = await manager.nextBatches();
      expect(batches.length, 3);
    });
  });
}

class _TestJsonSerializer extends JsonSerializer {
  @override
  String encode(LogEvent event) {
    return '{"id":"${event.recordId}"}';
  }
}

LogEvent _fakeEvent(String id) {
  return LogEvent(
    recordId: id,
    payload: const {'message': 'test'},
  );
}
