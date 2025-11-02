import 'package:file/file.dart';

import '../models/log_event.dart';
import '../utils/json_serializer.dart';

/// Configuration describing how log files are laid out on disk.
class LogPersistenceConfig {
  const LogPersistenceConfig({
    required this.rootDirectory,
    required this.metadataFileName,
    required this.filePrefix,
    required this.fileExtension,
    required this.maxRecordsPerFile,
    required this.maxBytesPerFile,
  });

  final String rootDirectory;
  final String metadataFileName;
  final String filePrefix;
  final String fileExtension;
  final int maxRecordsPerFile;
  final int maxBytesPerFile;
}

/// Summary of a pending batch on disk.
class PendingBatch {
  const PendingBatch({
    required this.filename,
    required this.recordCount,
    required this.sizeBytes,
    required this.oldestRecordId,
  });

  final String filename;
  final int recordCount;
  final int sizeBytes;
  final String oldestRecordId;
}

/// Snapshot of persisted metadata used for idempotency.
class LogPersistenceState {
  const LogPersistenceState({
    required this.lastUploadedRecordId,
    required this.activeBatchFile,
  });

  final String? lastUploadedRecordId;
  final String? activeBatchFile;
}

/// File-backed persistence layer following the architecture specification.
class FileLogPersistence {
  FileLogPersistence({
    required this.fileSystem,
    required this.serializer,
    required this.config,
  });

  final FileSystem fileSystem;
  final JsonSerializer serializer;
  final LogPersistenceConfig config;

  Future<void> initialize() {
    return fileSystem.directory(config.rootDirectory).create(recursive: true);
  }

  Future<void> append(LogEvent event) => throw UnimplementedError();

  Future<List<PendingBatch>> pendingBatches() => throw UnimplementedError();

  Future<void> markBatchUploaded(
    String filename, {
    required String highWaterMark,
  }) =>
      throw UnimplementedError();

  Future<LogPersistenceState> loadState() => throw UnimplementedError();
}
