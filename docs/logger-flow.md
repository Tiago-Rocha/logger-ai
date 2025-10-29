# `Logger.log()` Flow

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
