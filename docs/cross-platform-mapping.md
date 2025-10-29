# Cross-Platform Mapping

| `LogUploadPolicy` Field | Android Implementation | iOS Implementation |
|--------------------------|------------------------|--------------------|
| `frequency` | `PeriodicWorkRequest(interval)` | `BGProcessingTaskRequest(earliestBeginDate)` |
| `wifiOnly` | `setRequiredNetworkType(UNMETERED)` | Checked via `NWPathMonitor` before scheduling |
| `chargingOnly` | `setRequiresCharging(true)` | Skip scheduling if not charging (`UIDevice.batteryState`) |
| `idleRequired` | `setRequiresDeviceIdle(true)` | Ignored (no equivalent API) |
| `retry` | WorkManager backoff policy | Manual reschedule + URLSession retry |
| `expiration` | WorkManager’s job timeout | `expirationHandler` in BG task |
| `osManaged` | WorkManager KEEP policy | BGAppRefreshTask / OS heuristics |
