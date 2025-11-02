/// Additional context associated with a log event (timestamps, device info).
class LogMetadata {
  LogMetadata({
    required DateTime timestamp,
    Map<String, Object?> attributes = const <String, Object?>{},
  })  : timestamp = timestamp.toUtc(),
        attributes = Map.unmodifiable(Map<String, Object?>.from(attributes));

  /// Time when the log entry was produced (UTC recommended).
  final DateTime timestamp;

  /// Additional metadata supplied by the host application.
  final Map<String, Object?> attributes;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'timestamp': timestamp.toUtc().toIso8601String(),
      'attributes': attributes,
    };
  }
}
