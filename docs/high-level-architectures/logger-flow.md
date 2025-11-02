# Logger Flow (Foreground → Background → Backend)

```
Host App
  ↓
[1] LogCollector.record(recordId, payload)
     → normalises into LogEvent
     → injects timestamp + metadata
     → notifies delegate.onEventRecorded / onEventRejected

  ↓
[2] FileLogPersistence
     → appends NDJSON to crash-safe queue
     → rotates files by count / size

  ↓
[3] BatchManager
     → groups pending files according to LogUploadPolicy
     → caps batches per upload cycle

  ↓
[4] BackgroundScheduler (WorkManager/BGTaskScheduler)
     → configureScheduling(schedule)
     → triggers `_runScheduledUpload`
     → cancelScheduling() removes future work

  ↓
[5] UploadManager.upload(batches)
     → streams batches to backend (host-provided implementation)
     → returns UploadResult with per-batch high-water marks
     → delegate.onUploadSuccess / onUploadFailure invoked

  ↓
[6] FileLogPersistence.markBatchUploaded
     → deletes acknowledged files
     → records last uploaded recordId (idempotency)

  ↓
[7] Backend
     → deduplicates by recordId
     → responds with acknowledgement/high-water mark
```
