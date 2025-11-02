import '../models/log_event.dart';
import '../models/log_metadata.dart';
import '../persistence/log_persistence.dart';
import '../hooks/logger_delegate.dart';

typedef Clock = DateTime Function();

/// Handles validation, enrichment, and serialization of incoming log events.
class LogCollector {
  LogCollector({
    required FileLogPersistence persistence,
    Clock? clock,
    LoggerDelegate? delegate,
  })  : _persistence = persistence,
        _clock = clock ?? DateTime.now,
        _delegate = delegate;

  final FileLogPersistence _persistence;
  final Clock _clock;
  final LoggerDelegate? _delegate;

  /// Records a structured log event.
  Future<void> record({
    required String recordId,
    required Map<String, Object?> payload,
    LogMetadata? metadata,
  }) async {
    if (recordId.trim().isEmpty) {
      final error =
          ArgumentError.value(recordId, 'recordId', 'must not be empty');
      _delegate?.onEventRejected(recordId, error);
      throw error;
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
    _delegate?.onEventRecorded(event);
  }
}
