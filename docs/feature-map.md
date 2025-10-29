# Feature Map (MVP → Advanced)

| Tier | Feature | Purpose | Implementation Hint |
|------|----------|----------|----------------------|
| **MVP Layer 1: Core Logging** | `Logger.log(level, message)` | Unified logging API | Simple in-memory + file append |
|  | Contextual metadata | Add useful info for debugging | Automatic injection |
| **MVP Layer 2: Persistence** | Local file queue (WAL) | Survive crashes | Append JSON lines to file |
|  | Flush on demand | Manual upload | Trigger HTTP POST |
| **MVP Layer 3: Background Upload** | Scheduled upload | Works in background | WorkManager / BGTaskScheduler |
|  | Retry & backoff | Network resilience | Exponential retry |
| **Optional Layer 4: Constraints** | Wi-Fi only / charging only | Power & data control | OS flags |
|  | Idle-only (Android) | Save battery | WorkManager constraint |
| **Optional Layer 5: Idempotency** | Avoid duplicates | Reliability | recordId + ACK |
| **Optional Layer 6: Compression & Encryption** | Efficiency & privacy | gzip + AES-GCM |
| **Optional Layer 7: Observability** | SDK metrics | Internal telemetry | Counters for bytes, retries |
| **Optional Layer 8: Developer Hooks** | Success/failure delegate | Host visibility | `onUploadSuccess`, etc. |
