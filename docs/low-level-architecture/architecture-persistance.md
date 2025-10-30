
# 💾 Logger SDK Persistence Layer

This document explains how the **Logger SDK** ensures reliability and durability of logs
through a lightweight **Write-Ahead Log (WAL)** system using **append-only JSON files**.

---

## 🧩 Concept Overview

When the SDK receives a new log entry via `Logger.log()`, it **immediately writes it to disk**
as a JSON line.  
This guarantees that even if the app crashes or the device loses power, the log remains safe
and will be uploaded when the app restarts.

> ✅ **Key goal:** Never lose a log once `Logger.log()` is called.

---

## 🪶 The JSON File Queue

Each log is serialized into a single JSON line and appended to an active file.

Example structure on disk:
```
logs/
 ├── batch_001.jsonl
 ├── batch_002.jsonl
 └── batch_003.jsonl
```

Each `.jsonl` file contains multiple log records:
```json
{"id":"01J123","ts":1730200000000,"lvl":"info","msg":"App started"}
{"id":"01J124","ts":1730200000100,"lvl":"warn","msg":"Low battery"}
{"id":"01J125","ts":1730200000200,"lvl":"error","msg":"Crash detected"}
```

When the current file reaches a threshold (e.g., 1MB or 500 records),
it is **rotated** and a new file begins.  
Older files are uploaded first.

---

## 🔄 Lifecycle

```
Logger.log() called
   ↓
[1] Append JSON line → current WAL file
   ↓
[2] Background uploader picks oldest files
   ↓
[3] Uploads batch → backend endpoint
   ↓
[4] On ACK → deletes those files
   ↓
[5] Continues with next batch
```

### Metadata Tracking (High-Water Mark)

A small metadata file (e.g., `state.json`) keeps track of the last acknowledged record:

```json
{
  "lastUploadedId": "01J125",
  "currentFile": "batch_003.jsonl"
}
```

This checkpoint ensures **idempotency**:  
if a batch was already uploaded, it won’t be sent again.

---

## ⚙️ Advantages of JSONL WAL Approach

| Benefit | Description |
|----------|-------------|
| **Crash Safety** | Logs survive app restarts or system crashes. |
| **Performance** | Sequential appends are extremely fast. |
| **Cross-Platform Simplicity** | Works on both iOS & Android without DB dependencies. |
| **Idempotency** | Easy to mark completed uploads by deleting files. |
| **Low Overhead** | No SQL engine or schema migrations. |
| **Scalable** | File rotation keeps disk usage predictable. |

---

## 🚫 When to Consider a Database

SQLite or Realm could be used **only if**:
- You expect millions of logs per session.
- You need indexed search or filtering by field.
- Logs must be queried or joined with other data.

Otherwise, JSONL files are **simpler, safer, and more portable**.

---

## 🧱 Diagram: WAL in Action

```
 ┌──────────────────────────── Logger API ─────────────────────────────┐
 │                                                                    │
 │  Logger.log("txn_approved", {...})                                 │
 │    ↓                                                              │
 │  [Serialize LogEvent → JSON Line]                                  │
 │    ↓                                                              │
 │  Append to WAL File (NDJSON)                                       │
 │                                                                    │
 └────────────────────────────────────────────────────────────────────┘

                     (Disk Storage)
                     ┌────────────────────────────────────┐
                     │ logs/                              │
                     │  ├── batch_001.jsonl               │
                     │  │   {"id":"01A","msg":"Started"}  │
                     │  │   {"id":"01B","msg":"Login"}    │
                     │  │   {"id":"01C","msg":"Error"}    │
                     │  ├── batch_002.jsonl               │
                     │  │   {"id":"01D","msg":"Txn"}      │
                     │  └── ...                           │
                     └────────────────────────────────────┘
                                   ↓
                          (Background Worker)
                                   ↓
 ┌──────────────────────────── Upload Manager ─────────────────────────┐
 │                                                                    │
 │  1️⃣ Read oldest batch file (e.g. batch_001.jsonl)                 │
 │  2️⃣ Compress/encrypt if needed                                    │
 │  3️⃣ POST → https://logs.example.com/v1/logs                       │
 │  4️⃣ Await server ACK (with high-water-mark)                       │
 │  5️⃣ On success → delete batch_001.jsonl                           │
 │  6️⃣ On failure → retry with backoff                               │
 │                                                                    │
 └────────────────────────────────────────────────────────────────────┘

 (Server)
 ┌────────────────────────────────────────────────────────────────────┐
 │ Receives batch → deduplicates via recordId                         │
 │ Responds with { "accepted": true, "hwm": "01C" }                   │
 │ SDK marks files ≤ HWM as safe to delete                            │
 └────────────────────────────────────────────────────────────────────┘

✅ No log loss even if app crashes mid-upload  
✅ Sequential, efficient disk I/O  
✅ Idempotent (safe against duplicates)
```

---

## 🧠 TL;DR for Interview Use

> “For persistence, I’d use an append-only NDJSON file system that works like a write-ahead log.  
> Every log is written immediately and safely to disk, then uploaded in batches.  
> Once the backend confirms receipt, those files are deleted.  
> It’s simple, durable, and works consistently across both iOS and Android.”
