import '../models/log_event.dart';

/// Delegate interface for host applications to observe SDK lifecycle events.
abstract class LoggerDelegate {
  /// Called when the SDK successfully records a log event through the collector.
  void onEventRecorded(LogEvent event) {}

  /// Called when the SDK rejects a record request (validation failure, etc.).
  void onEventRejected(String recordId, Object error) {}
}
