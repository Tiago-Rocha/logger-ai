/// Represents a log record ready to be serialized to NDJSON.
class LogEvent {
  const LogEvent({
    required this.recordId,
    required this.payload,
  });

  final String recordId;
  final Map<String, Object?> payload;
}
