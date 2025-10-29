
# 🧩 Cross-Platform Logger SDK Design Summary

This SDK provides a **unified logging interface** for iOS and Android.  
It allows host apps to:
- Log structured events via a simple API.
- Persist logs locally to survive crashes or restarts.
- Upload logs automatically in the background.
- Configure upload frequency and constraints via a declarative `LogUploadPolicy`.
- Receive success/failure callbacks.
- Guarantee idempotent delivery.

---

## 1️⃣ High-Level Architecture

```
┌────────────────────────────── App Layer ───────────────────────────────┐
│ Host app calls:                                                       │
│   Logger.register()                                                   │
│   Logger.configure(policy)                                            │
│   Logger.log("AppStarted", {...})                                     │
└───────────────┬────────────────────────────────────────────────────────┘
                │
                ▼
┌────────────────────────────── SDK Core ────────────────────────────────┐
│ 1️⃣ Log Collector                                                     │
│     - Formats message + metadata (timestamp, level, tags).             │
│                                                                       │
│ 2️⃣ Persistence (WAL / Queue)                                        │
│     - Writes JSON lines to rotating files (safe on crash).             │
│                                                                       │
│ 3️⃣ Batch Manager                                                    │
│     - Groups logs by size/time. Compresses/encrypts if needed.         │
│                                                                       │
│ 4️⃣ Upload Manager                                                   │
│     - Uses OS schedulers (WorkManager / BGTaskScheduler).              │
│     - Retries with exponential backoff.                               │
│                                                                       │
│ 5️⃣ Delegate / Hooks                                                │
│     - onUploadSuccess / onUploadFailure callbacks.                     │
└───────────────┬────────────────────────────────────────────────────────┘
                │
                ▼
┌────────────────────────────── OS Services ─────────────────────────────┐
│ Android → WorkManager + OkHttp + constraints                           │
│ iOS     → BGTaskScheduler + URLSession(background:)                    │
└───────────────┬────────────────────────────────────────────────────────┘
                │
                ▼
┌────────────────────────────── Backend ─────────────────────────────────┐
│ - Accepts batched JSON logs                                            │
│ - Dedupe by recordId                                                   │
│ - Returns ACK (high-water-mark)                                        │
│ - Persists logs for analytics                                          │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2️⃣ `Logger.log()` Flow

```
Host App
  ↓
[1] Logger.log(key, data)
     → Example: Logger.log("txn_approved", ["id": "TX123"])

  ↓
[2] Normalization Layer
     → Converts to structured LogEvent
     → Adds timestamp, log level, sessionId
     → Serializes internally (JSON)

  ↓
[3] Persistence Layer
     → Writes to local file / database (WAL)
     → Safe if app crashes or restarts

  ↓
[4] Upload Manager
     → Reads pending batches
     → Compress + encrypt (if configured)
     → POST to backend

  ↓
[5] Delegate / Callback
     → onSuccess(batchId)
     → onFailure(error)

  ↓
[6] Backend
     → Dedupe by recordId / batchId
     → Return ACK (high-water-mark)
```

---

## 3️⃣ `LogUploadPolicy` Model

A **declarative configuration object** that defines when and how logs are uploaded.  
Each platform adapts it to its native background work API.

```swift
struct LogUploadPolicy {
    var frequency: UploadFrequency
    var constraints: UploadConstraints
    var retry: RetryPolicy?
    var expiration: TimeInterval?
    var taskIdentifier: String = "com.seamlesspay.logger.upload"
}

enum UploadFrequency {
    case interval(TimeInterval)  // every 15 min
    case onAppLaunch
    case osManaged               // system decides
}

struct UploadConstraints {
    var wifiOnly: Bool
    var chargingOnly: Bool
    var idleRequired: Bool   // Android only
    var minBatteryLevel: Float?
}

struct RetryPolicy {
    var maxRetries: Int
    var backoffStrategy: BackoffStrategy
}

enum BackoffStrategy {
    case fixed(seconds: TimeInterval)
    case exponential(base: Double)
}
```

**Key principles**
- Declarative, not imperative (describes intent).  
- Platform-agnostic mapping.  
- Extensible without breaking API.  
- Same interface for both iOS and Android.

---

## 4️⃣ Feature Map (MVP → Advanced)

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

---

## 5️⃣ Cross-Platform Mapping Table

| `LogUploadPolicy` Field | Android Implementation | iOS Implementation |
|--------------------------|------------------------|--------------------|
| `frequency` | `PeriodicWorkRequest(interval)` | `BGProcessingTaskRequest(earliestBeginDate)` |
| `wifiOnly` | `setRequiredNetworkType(UNMETERED)` | Checked via `NWPathMonitor` before scheduling |
| `chargingOnly` | `setRequiresCharging(true)` | Skip scheduling if not charging (`UIDevice.batteryState`) |
| `idleRequired` | `setRequiresDeviceIdle(true)` | Ignored (no equivalent API) |
| `retry` | WorkManager backoff policy | Manual reschedule + URLSession retry |
| `expiration` | WorkManager’s job timeout | `expirationHandler` in BG task |
| `osManaged` | WorkManager KEEP policy | BGAppRefreshTask / OS heuristics |

---

## 🎯 Interview Talking Points

✅ **API clarity** – host app only uses `register`, `configure`, `log`, `delegate`.  
✅ **Persistence** – logs stored locally, guaranteeing delivery even after crash.  
✅ **Declarative configuration** – `LogUploadPolicy` describes *intent*; adapters translate to native schedulers.  
✅ **Feedback loop** – delegate communicates success/failure back to app.  
✅ **Idempotency** – batches deduplicated using `recordId` or `batchId`.  
✅ **Testing strategy** –  
   - Unit: policy validation, mapping correctness.  
   - Fakes: simulate WorkManager/BGTaskScheduler.  
   - Integration: end-to-end log→upload flow.  
   - Contract: cross-platform parity.  
   - Edge: offline, crash, battery-low.  

---

## 🧠 Example Closing Line for Interview

> “The SDK provides a unified, declarative API for reliable background log uploads across iOS and Android.  
> It abstracts platform differences through a `LogUploadPolicy` adapter layer, persists logs locally for crash resilience, and provides feedback via a delegate.  
> The design prioritizes clarity, reliability, and cross-platform parity.”
