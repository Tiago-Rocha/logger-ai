# 📦 Logger SDK Batch Manager Architecture

This document explains how the **Batch Manager** component groups individual logs into
optimized batches for efficient upload and network utilization.

---

## 🧩 Concept Overview

The **Batch Manager** sits between the Persistence layer and Upload Manager.
It continuously monitors stored logs and intelligently groups them into batches based on:

1. **Size thresholds** (e.g., 1MB per batch)
2. **Time windows** (e.g., every 30 seconds)
3. **Count limits** (e.g., 500 logs per batch)
4. **Network conditions** (WiFi vs cellular)

> ✅ **Key goal:** Optimize upload efficiency while respecting device resources and network constraints.

---

## 🏗️ Component Structure

```
┌──────────────────────────── Batch Manager ─────────────────────────────┐
│                                                                        │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────────┐  │
│  │   Monitor       │───▶│   Grouper       │───▶│   Processor         │  │
│  │                 │    │                 │    │                     │  │
│  │ • File watcher  │    │ • Size-based    │    │ • Compression       │  │
│  │ • Timer triggers│    │ • Time-based    │    │ • Encryption        │  │
│  │ • Event signals │    │ • Priority      │    │ • Validation        │  │
│  │ • Threshold     │    │   sorting       │    │ • Metadata          │  │
│  │   checks        │    │ • Deduplication │    │   enrichment        │  │
│  └─────────────────┘    └─────────────────┘    └─────────────────────┘  │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 📊 Batching Strategies

### 1. Size-Based Batching
Groups logs until reaching a target size (optimizes network usage):

```
┌─ Batch 1 (1.2MB) ─┐  ┌─ Batch 2 (0.8MB) ─┐  ┌─ Batch 3 (Building...) ─┐
│ log_001.json      │  │ log_150.json      │  │ log_275.json            │
│ log_002.json      │  │ log_151.json      │  │ log_276.json            │
│ ...               │  │ ...               │  │ ...                     │
│ log_149.json      │  │ log_274.json      │  │                         │
│ [Ready for upload]│  │ [Ready for upload]│  │ [Waiting for more logs] │
└───────────────────┘  └───────────────────┘  └─────────────────────────┘
```

### 2. Time-Based Batching
Ensures logs don't wait too long before upload:

```
Timeline: 0s ────── 30s ────── 60s ────── 90s ──────▶

Batch A: [logs from 0-30s]    → Upload at 30s
Batch B: [logs from 30-60s]   → Upload at 60s  
Batch C: [logs from 60-90s]   → Upload at 90s
```

### 3. Hybrid Strategy (Recommended)
Combines both approaches for optimal efficiency:

```python
def shouldCreateBatch(currentBatch):
    return (
        currentBatch.sizeBytes >= TARGET_SIZE_BYTES or
        currentBatch.ageSeconds >= MAX_AGE_SECONDS or
        currentBatch.logCount >= MAX_LOG_COUNT or
        networkCondition == EXCELLENT
    )
```

---

## 🔄 Batch Lifecycle

```
┌─────────────────── Accumulation Phase ────────────────────┐
│                                                          │
│  New logs arrive → Add to current batch                  │
│  Monitor: size, count, age                               │
│  Trigger: threshold reached                              │
│                                                          │
└─────────────────────────────┬────────────────────────────┘
                              ▼
┌─────────────────── Processing Phase ──────────────────────┐
│                                                          │
│  1️⃣ Validate batch integrity                             │
│  2️⃣ Remove duplicates (by recordId)                      │
│  3️⃣ Sort by timestamp (chronological order)             │
│  4️⃣ Apply compression (gzip/deflate)                     │
│  5️⃣ Add batch metadata (id, timestamp, checksum)        │
│  6️⃣ Encrypt if required                                  │
│                                                          │
└─────────────────────────────┬────────────────────────────┘
                              ▼
┌─────────────────── Ready for Upload ──────────────────────┐
│                                                          │
│  Batch stored in upload queue                            │
│  Upload Manager notified                                 │
│  Original log files marked for cleanup (after upload)   │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

---

## 🎛️ Configuration Options

The Batch Manager supports flexible configuration:

```json
{
  "batching": {
    "strategy": "hybrid", // "size", "time", "hybrid"
    "maxSizeBytes": 1048576, // 1MB
    "maxAgeDurationMs": 30000, // 30 seconds
    "maxLogCount": 500,
    "compressionEnabled": true,
    "compressionAlgorithm": "gzip", // "gzip", "deflate", "none"
    "encryptionEnabled": false,
    "dedupEnabled": true
  },
  "networkAdaptive": {
    "enabled": true,
    "wifiSizeMultiplier": 2.0, // Larger batches on WiFi
    "cellularMaxSize": 512000, // 512KB on cellular
    "lowBatteryReduction": 0.5 // Smaller batches when battery low
  }
}
```

---

## 📦 Batch Format

### Individual Log Entry
```json
{
  "id": "01JBQR7X8P9K2M3N4Q5R6S7T8V",
  "ts": 1730200000123,
  "lvl": "info",
  "msg": "user_login",
  "data": {"userId": "user123"},
  "meta": {"sessionId": "sess_abc", "platform": "iOS"}
}
```

### Batch Container
```json
{
  "batchId": "batch_01JBQR7Y9QAKBMCNDPEQFRHSGW",
  "createdAt": 1730200030000,
  "logCount": 150,
  "sizeBytes": 1048576,
  "checksum": "sha256:a1b2c3d4...",
  "compression": "gzip",
  "logs": [
    /* Array of log entries sorted by timestamp */
  ]
}
```

---

## 🚦 Priority & Ordering

### Log Priority Levels
1. **Critical** - Errors, crashes (upload immediately)
2. **High** - Warnings, performance issues  
3. **Normal** - Standard app events
4. **Low** - Debug information, verbose logs

### Batch Ordering Strategy
```kotlin
fun createBatch(availableLogs: List<LogEntry>): Batch {
    return availableLogs
        .sortedWith(compareBy<LogEntry> { it.priority.ordinal }
            .thenBy { it.timestamp })
        .take(maxLogCount)
        .let { Batch.create(it) }
}
```

---

## 🔧 Platform-Specific Implementation

### Android (Kotlin)
```kotlin
class BatchManager(
    private val config: BatchConfig,
    private val storage: LogStorage,
    private val scheduler: JobScheduler
) {
    private val currentBatch = AtomicReference<BatchBuilder>()
    
    fun processPendingLogs() {
        val logs = storage.getUnbatchedLogs()
        val batches = createBatches(logs)
        
        batches.forEach { batch ->
            val compressedBatch = compressor.compress(batch)
            storage.storeBatch(compressedBatch)
            notifyUploadManager(compressedBatch.id)
        }
    }
}
```

### iOS (Swift)
```swift
class BatchManager {
    private let config: BatchConfig
    private let storage: LogStorage
    private var currentBatch: BatchBuilder?
    
    func processPendingLogs() {
        let logs = storage.getUnbatchedLogs()
        let batches = createBatches(from: logs)
        
        for batch in batches {
            let compressedBatch = compressor.compress(batch)
            storage.store(batch: compressedBatch)
            notifyUploadManager(batchId: compressedBatch.id)
        }
    }
}
```

---

## 📊 Performance Optimizations

### Memory Management
- **Streaming processing:** Don't load entire batches into memory
- **Buffer reuse:** Recycle compression/serialization buffers
- **Lazy loading:** Load log content only when needed

### Disk I/O
- **Sequential reads:** Process logs in file order
- **Batch writes:** Write completed batches atomically
- **Cleanup scheduling:** Remove processed files during idle time

### CPU Usage
- **Background threading:** Process batches off main thread
- **Incremental compression:** Compress as logs are added
- **Caching:** Cache batch metadata for quick lookups

---

## 🧠 TL;DR for Interview Use

> "The Batch Manager is like a smart loading dock for logs. It watches incoming logs and groups them into optimal batches based on size, time, and network conditions. It can compress and encrypt batches, remove duplicates, and prioritize critical logs. The goal is to minimize network requests while ensuring logs don't wait too long for upload. It's essentially an intelligent buffer between individual log events and bulk network operations."