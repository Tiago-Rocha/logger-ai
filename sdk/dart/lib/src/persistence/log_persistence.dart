import 'dart:convert';
import 'dart:math';

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

  Directory? _rootDirectory;
  File? _metadataFile;
  LogPersistenceState _state = const LogPersistenceState(
      lastUploadedRecordId: null, activeBatchFile: null);
  bool _initialized = false;

  String? _activeBatchFile;
  int _activeRecordCount = 0;
  int _activeByteCount = 0;
  int _nextFileIndex = 1;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    final root = fileSystem.directory(config.rootDirectory);
    await root.create(recursive: true);
    _rootDirectory = root;

    final metadataFile = fileSystem.file(
      fileSystem.path.join(config.rootDirectory, config.metadataFileName),
    );
    if (!await metadataFile.exists()) {
      await metadataFile.create(recursive: true);
      await metadataFile.writeAsString(jsonEncode(_stateToJson(_state)));
    } else {
      _state = await _readMetadata(metadataFile);
    }
    _metadataFile = metadataFile;

    await _synchroniseActiveFile();
    _initialized = true;
  }

  Future<void> append(LogEvent event) async {
    await _ensureInitialized();
    final entry = '${serializer.encode(event)}\n';

    if (_activeBatchFile == null) {
      _rotateToNewBatch();
    }

    final exceedsRecords = _activeRecordCount >= config.maxRecordsPerFile;
    final exceedsBytes =
        _activeByteCount + entry.length > config.maxBytesPerFile;

    if (exceedsRecords || exceedsBytes) {
      _rotateToNewBatch();
    }

    final file = _batchFile(_activeBatchFile!);
    await file.writeAsString(entry, mode: FileMode.append, flush: true);

    _activeRecordCount += 1;
    _activeByteCount += entry.length;
    _state = LogPersistenceState(
      lastUploadedRecordId: _state.lastUploadedRecordId,
      activeBatchFile: _activeBatchFile,
    );
    await _writeMetadata();
  }

  Future<List<PendingBatch>> pendingBatches() async {
    await _ensureInitialized();
    final files = _batchFiles();
    final batches = <PendingBatch>[];
    for (final file in files) {
      final filename = fileSystem.path.basename(file.path);
      final contents = await file.readAsLines();
      final lines = contents.where((line) => line.isNotEmpty).toList();
      final recordCount = lines.length;
      final sizeBytes = await file.length();
      final oldestRecordId = lines.isEmpty ? '' : _extractRecordId(lines.first);
      batches.add(
        PendingBatch(
          filename: filename,
          recordCount: recordCount,
          sizeBytes: sizeBytes,
          oldestRecordId: oldestRecordId,
        ),
      );
    }
    batches.sort((a, b) => a.filename.compareTo(b.filename));
    return batches;
  }

  Future<void> markBatchUploaded(
    String filename, {
    String? highWaterMark,
  }) async {
    await _ensureInitialized();
    final file = _batchFile(filename);
    String? derivedHighWaterMark =
        highWaterMark == null || highWaterMark.isEmpty ? null : highWaterMark;
    if (derivedHighWaterMark == null && await file.exists()) {
      final lines = await file.readAsLines();
      if (lines.isNotEmpty) {
        final lastLine = lines.lastWhere((line) => line.isNotEmpty,
            orElse: () => lines.last);
        derivedHighWaterMark = _extractRecordId(lastLine);
      }
    }
    if (await file.exists()) {
      await file.delete();
    }

    if (_activeBatchFile == filename) {
      _activeBatchFile = null;
      _activeRecordCount = 0;
      _activeByteCount = 0;
    }

    final remaining = _batchFiles();
    final nextActive = remaining.isEmpty
        ? null
        : fileSystem.path.basename(remaining.first.path);

    _state = LogPersistenceState(
      lastUploadedRecordId: derivedHighWaterMark,
      activeBatchFile: nextActive,
    );
    await _writeMetadata();
    await _synchroniseActiveFile();
  }

  Future<LogPersistenceState> loadState() async {
    await _ensureInitialized();
    return _state;
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  Future<void> _writeMetadata() async {
    final file = _metadataFile;
    if (file == null) {
      return;
    }
    await file.writeAsString(jsonEncode(_stateToJson(_state)));
  }

  Future<void> _synchroniseActiveFile() async {
    final activeName = _state.activeBatchFile;
    final files = _batchFiles();
    if (files.isNotEmpty) {
      final indices = files
          .map((file) => _extractIndex(fileSystem.path.basename(file.path)))
          .toList();
      _nextFileIndex = indices.fold<int>(1, (previousValue, element) {
        return max(previousValue, element + 1);
      });
    } else {
      _nextFileIndex = 1;
    }

    if (activeName != null) {
      final file = _batchFile(activeName);
      if (await file.exists()) {
        final lines = await file.readAsLines();
        _activeBatchFile = activeName;
        _activeRecordCount = lines.where((line) => line.isNotEmpty).length;
        _activeByteCount = await file.length();
        return;
      }
    }

    _activeBatchFile = null;
    _activeRecordCount = 0;
    _activeByteCount = 0;
  }

  void _rotateToNewBatch() {
    final filename =
        '${config.filePrefix}${_nextFileIndex.toString().padLeft(3, '0')}${config.fileExtension}';
    _nextFileIndex += 1;
    _activeBatchFile = filename;
    _activeRecordCount = 0;
    _activeByteCount = 0;
  }

  List<File> _batchFiles() {
    final directory = _rootDirectory;
    if (directory == null || !directory.existsSync()) {
      return [];
    }
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => _isBatchFile(fileSystem.path.basename(file.path)))
        .toList()
      ..sort((a, b) => fileSystem.path
          .basename(a.path)
          .compareTo(fileSystem.path.basename(b.path)));
    return files;
  }

  File _batchFile(String filename) {
    return fileSystem.file(
      fileSystem.path.join(config.rootDirectory, filename),
    );
  }

  bool _isBatchFile(String filename) {
    return filename.startsWith(config.filePrefix) &&
        filename.endsWith(config.fileExtension);
  }

  int _extractIndex(String filename) {
    final withoutPrefix = filename.substring(config.filePrefix.length,
        filename.length - config.fileExtension.length);
    return int.tryParse(withoutPrefix) ?? 0;
  }

  String _extractRecordId(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is Map<String, dynamic>) {
        final recordId =
            decoded['recordId'] ?? decoded['record_id'] ?? decoded['id'];
        if (recordId is String) {
          return recordId;
        }
      }
    } catch (_) {
      // Ignore parse errors and fall through to empty string.
    }
    return '';
  }

  Future<LogPersistenceState> _readMetadata(File file) async {
    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return const LogPersistenceState(
          lastUploadedRecordId: null,
          activeBatchFile: null,
        );
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return LogPersistenceState(
          lastUploadedRecordId: decoded['lastUploadedRecordId'] as String?,
          activeBatchFile: decoded['activeBatchFile'] as String?,
        );
      }
    } catch (_) {
      // Fall through to default state.
    }
    return const LogPersistenceState(
      lastUploadedRecordId: null,
      activeBatchFile: null,
    );
  }

  Map<String, Object?> _stateToJson(LogPersistenceState state) {
    return <String, Object?>{
      'lastUploadedRecordId': state.lastUploadedRecordId,
      'activeBatchFile': state.activeBatchFile,
    };
  }
}
