import '../models/log_event.dart';
import '../models/log_metadata.dart';
import '../persistence/log_persistence.dart';

typedef Clock = DateTime Function();

/// Handles validation, enrichment, and serialization of incoming log events.
class LogCollector {
  LogCollector({
    required FileLogPersistence persistence,
    Clock? clock,
  })  : _persistence = persistence,
        _clock = clock ?? DateTime.now;

  final FileLogPersistence _persistence;
  final Clock _clock;

  /// Records a structured log event.
  Future<void> record({
    required String recordId,
    required Map<String, Object?> payload,
    LogMetadata? metadata,
  }) async {
    if (recordId.trim().isEmpty) {
      throw ArgumentError.value(recordId, 'recordId', 'must not be empty');
    }
    final normalisedPayload = Map<String, Object?>.from(payload);
    final eventMetadata = metadata ??
        LogMetadata(
          timestamp: _clock().toUtc(),
        );
    final event = LogEvent(
      recordId: recordId,
      payload: normalisedPayload,
      metadata: eventMetadata,
    );
    await _persistence.append(event);
  }
}
