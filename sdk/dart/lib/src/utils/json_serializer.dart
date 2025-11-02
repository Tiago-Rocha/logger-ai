import '../models/log_event.dart';

/// Serialization helpers for turning log events into transport formats.
abstract class JsonSerializer {
  const JsonSerializer();

  /// Converts the event into a newline-delimited JSON string representation.
  String encode(LogEvent event);
}
