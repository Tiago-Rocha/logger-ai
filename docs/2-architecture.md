# High-Level Architecture

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
│ 1️⃣ Log Collector → [📝 architecture-log-collector.md]                │
│     - Formats message + metadata (timestamp, level, tags).             │
│                                                                       │
│ 2️⃣ Persistence (WAL / Queue) → [💾 architecture-persistance.md]      │
│     - Writes JSON lines to rotating files (safe on crash).             │
│                                                                       │
│ 3️⃣ Batch Manager → [📦 architecture-batch-manager.md]               │
│     - Groups logs by size/time. Compresses/encrypts if needed.         │
│                                                                       │
│ 4️⃣ Upload Manager → [📡 architecture-upload-manager.md]             │
│     - Uses OS schedulers (WorkManager / BGTaskScheduler).              │
│     - Retries with exponential backoff.                               │
│                                                                       │
│ 5️⃣ Delegate / Hooks → [🔗 architecture-delegate-hooks.md]           │
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

---

## Detailed Architecture Documents

Each SDK Core component has its own detailed architecture document:

- **📝 [Log Collector Architecture](architecture-log-collector.md)** - Entry point validation, enrichment, and serialization
- **💾 [Persistence Architecture](architecture-persistance.md)** - Write-ahead log system using append-only JSON files  
- **📦 [Batch Manager Architecture](architecture-batch-manager.md)** - Intelligent grouping and optimization of logs for upload
- **📡 [Upload Manager Architecture](architecture-upload-manager.md)** - Reliable delivery with background scheduling and retry logic
- **🔗 [Delegate & Hooks Architecture](architecture-delegate-hooks.md)** - Extension points and observability system

These documents provide implementation details, code examples, and platform-specific considerations for each component.
```
