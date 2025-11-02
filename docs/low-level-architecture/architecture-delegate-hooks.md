# Logger Delegate & Upload Hooks

The Dart SDK exposes a compact delegate interface so host applications can observe
collector and upload activity without wiring into internal details.

```dart
abstract class LoggerDelegate {
  void onEventRecorded(LogEvent event) {}
  void onEventRejected(String recordId, Object error) {}
  void onUploadSuccess(List<String> batchFilenames) {}
  void onUploadFailure(List<String> batchFilenames, Object error) {}
}
```

## Collector Notifications
- **onEventRecorded** is invoked after `LogCollector.record` successfully
  serialises and enqueues an event.
- **onEventRejected** signals validation failures (for example, missing recordId).

The delegate is optional; pass it either to `LogCollector` or `LoggerSdk` via
`configureIntake`.

## Upload Notifications
- **onUploadSuccess** delivers the filenames acknowledged by the backend during
  a run. These values come directly from `UploadResult.batchHighWaterMarks`.
- **onUploadFailure** surfaces failed filenames and the error surfaced by the
  host-provided `UploadManager` implementation.

## Integrating the Delegate
1. Instantiate your delegate implementation.
2. Provide it to `LoggerSdk` during construction or via `configureIntake`.
3. Optionally provide it to `LogCollector` for symmetric event handling.

```
final delegate = MyLoggerDelegate();
final collector = LogCollector(persistence: persistence, delegate: delegate);
final sdk = LoggerSdk(
  scheduler: scheduler,
  uploadManager: uploadManager,
  delegate: delegate,
)..configureIntake(
    batchManager: batchManager,
    persistence: persistence,
    delegate: delegate,
  );
```

The delegate executes synchronously on the calling isolate, so keep callbacks
lightweight and offload heavy work to background isolates or platform channels
if necessary.
