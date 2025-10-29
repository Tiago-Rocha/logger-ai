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
