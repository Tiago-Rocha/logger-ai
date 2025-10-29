# 📡 Logger SDK Upload Manager Architecture

This document explains how the **Upload Manager** component handles reliable,
efficient delivery of log batches to backend services using platform-specific
background scheduling and robust retry mechanisms.

---

## 🧩 Concept Overview

The **Upload Manager** is responsible for the final mile of log delivery.
It takes processed batches from the Batch Manager and ensures they reach
the backend service reliably, even when:

- Network connectivity is intermittent
- The app is backgrounded or killed
- Device resources are constrained
- Backend services are temporarily unavailable

> ✅ **Key goal:** Guarantee eventual delivery of all log batches with optimal resource usage.

---

## 🏗️ Component Structure

```
┌──────────────────────────── Upload Manager ───────────────────────────┐
│                                                                       │
│  ┌─────────────────┐    ┌─────────────────┐    ┌───────────────────┐  │
│  │   Scheduler     │───▶│   Uploader      │───▶│   Retry Handler   │  │
│  │                 │    │                 │    │                   │  │
│  │ • Work queue    │    │ • HTTP client   │    │ • Exponential     │  │
│  │ • Constraints   │    │ • Auth headers  │    │   backoff         │  │
│  │ • Background    │    │ • Progress      │    │ • Circuit breaker │  │
│  │   tasks         │    │   tracking      │    │ • Dead letter     │  │
│  │ • Priority      │    │ • Compression   │    │   queue           │  │
│  └─────────────────┘    └─────────────────┘    └───────────────────┘  │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Upload Flow

```
Batch Ready for Upload
   ↓
┌─────────────────── Scheduling Phase ───────────────────┐
│ 1️⃣ Check network constraints (WiFi/cellular)          │
│ 2️⃣ Evaluate battery level                             │
│ 3️⃣ Schedule background task                           │
│ 4️⃣ Set retry policy                                   │
└─────────────────────────────┬───────────────────────────┘
   ↓
┌─────────────────── Upload Phase ──────────────────────┐
│ 1️⃣ Authenticate request                               │
│ 2️⃣ Apply compression/encryption                       │
│ 3️⃣ Send HTTP POST to backend                          │
│ 4️⃣ Monitor progress                                   │
│ 5️⃣ Handle response                                    │
└─────────────────────────────┬───────────────────────────┘
   ↓
┌─────────────────── Response Handling ─────────────────┐
│ ✅ Success (2xx): Mark batch uploaded, cleanup        │
│ 🔄 Retry (4xx/5xx): Apply backoff, reschedule        │
│ ❌ Fatal (auth): Mark failed, notify delegate         │
└───────────────────────────────────────────────────────┘
```

---

## 🎯 Platform-Specific Implementation

### Android: WorkManager Integration

```kotlin
class LogUploadWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val batchId = inputData.getString("batchId") ?: return Result.failure()
        
        return try {
            val batch = batchStorage.getBatch(batchId)
            val response = uploadBatch(batch)
            
            when (response.statusCode) {
                in 200..299 -> {
                    batchStorage.markUploaded(batchId)
                    Result.success()
                }
                in 400..499 -> {
                    // Client error - don't retry
                    logDelegate.onUploadFailed(batchId, "Client error: ${response.statusCode}")
                    Result.failure()
                }
                else -> {
                    // Server error - retry with backoff
                    Result.retry()
                }
            }
        } catch (e: NetworkException) {
            Result.retry()
        } catch (e: Exception) {
            logDelegate.onUploadFailed(batchId, e.message)
            Result.failure()
        }
    }
}

// Constraint-based scheduling
private fun scheduleUpload(batchId: String) {
    val constraints = Constraints.Builder()
        .setRequiredNetworkType(NetworkType.CONNECTED)
        .setRequiresBatteryNotLow(true)
        .build()

    val uploadWork = OneTimeWorkRequestBuilder<LogUploadWorker>()
        .setInputData(workDataOf("batchId" to batchId))
        .setConstraints(constraints)
        .setBackoffCriteria(
            BackoffPolicy.EXPONENTIAL,
            WorkRequest.MIN_BACKOFF_MILLIS,
            TimeUnit.MILLISECONDS
        )
        .build()

    WorkManager.getInstance().enqueue(uploadWork)
}
```

### iOS: BGTaskScheduler Integration

```swift
class UploadManager {
    private let backgroundTaskIdentifier = "com.app.logger.upload"
    
    func scheduleBackgroundUpload() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30) // Wait 30 seconds
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule background upload: \(error)")
        }
    }
    
    func handleBackgroundUpload(task: BGAppRefreshTask) {
        task.expirationHandler = {
            // Handle task expiration
            task.setTaskCompleted(success: false)
        }
        
        Task {
            do {
                await uploadPendingBatches()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
                scheduleRetry()
            }
        }
    }
    
    private func uploadBatch(_ batch: LogBatch) async throws -> UploadResponse {
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        
        // Compress batch if needed
        let data = try compressIfNeeded(batch.jsonData)
        request.httpBody = data
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }
        
        return try handleResponse(httpResponse, data: responseData)
    }
}
```

---

## 🔄 Retry Strategy

### Exponential Backoff with Jitter

```
Attempt 1: Immediate
Attempt 2: 1s + random(0-1s)
Attempt 3: 2s + random(0-2s)  
Attempt 4: 4s + random(0-4s)
Attempt 5: 8s + random(0-8s)
...
Max delay: 300s (5 minutes)
Max attempts: 10
```

### Implementation

```kotlin
class RetryHandler {
    companion object {
        private const val BASE_DELAY_MS = 1000L
        private const val MAX_DELAY_MS = 300_000L // 5 minutes
        private const val MAX_ATTEMPTS = 10
    }
    
    fun calculateDelay(attemptNumber: Int): Long {
        if (attemptNumber >= MAX_ATTEMPTS) {
            throw MaxRetriesExceededException()
        }
        
        val exponentialDelay = BASE_DELAY_MS * (1L shl (attemptNumber - 1))
        val cappedDelay = minOf(exponentialDelay, MAX_DELAY_MS)
        val jitter = Random.nextLong(0, cappedDelay)
        
        return cappedDelay + jitter
    }
}
```

---

## 🌐 Network Optimization

### Connection Pooling
```kotlin
// Reuse connections for multiple uploads
private val httpClient = OkHttpClient.Builder()
    .connectionPool(ConnectionPool(5, 5, TimeUnit.MINUTES))
    .readTimeout(30, TimeUnit.SECONDS)
    .writeTimeout(30, TimeUnit.SECONDS)
    .build()
```

### Request Compression
```kotlin
private fun compressRequest(data: ByteArray): ByteArray {
    return ByteArrayOutputStream().use { baos ->
        GZIPOutputStream(baos).use { gzipOut ->
            gzipOut.write(data)
        }
        baos.toByteArray()
    }
}
```

### Progress Tracking
```swift
func uploadWithProgress(_ batch: LogBatch) async throws {
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        // Handle response
    }
    
    // Track upload progress
    let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
        delegate?.onUploadProgress(batchId: batch.id, progress: progress.fractionCompleted)
    }
    
    task.resume()
}
```

---

## 🔧 Configuration Options

```json
{
  "upload": {
    "endpoint": "https://logs.api.example.com/v1/batches",
    "timeoutSeconds": 30,
    "maxConcurrentUploads": 3,
    "retryPolicy": {
      "maxAttempts": 10,
      "baseDelayMs": 1000,
      "maxDelayMs": 300000,
      "backoffMultiplier": 2.0,
      "jitterEnabled": true
    },
    "constraints": {
      "requireWifi": false,
      "requireCharging": false,
      "requireBatteryNotLow": true,
      "requiredNetworkType": "connected"
    },
    "compression": {
      "enabled": true,
      "algorithm": "gzip",
      "minSizeBytes": 1024
    }
  }
}
```

---

## 📊 Monitoring & Observability

### Upload Metrics
```kotlin
data class UploadMetrics(
    val batchId: String,
    val attemptNumber: Int,
    val uploadDurationMs: Long,
    val requestSizeBytes: Long,
    val responseSizeBytes: Long,
    val statusCode: Int,
    val networkType: String, // "wifi", "cellular", "unknown"
    val batteryLevel: Float
)
```

### Success/Failure Tracking
```swift
protocol UploadDelegate {
    func onUploadStarted(batchId: String)
    func onUploadProgress(batchId: String, progress: Double)
    func onUploadCompleted(batchId: String, metrics: UploadMetrics)
    func onUploadFailed(batchId: String, error: Error, willRetry: Bool)
    func onUploadRetry(batchId: String, attemptNumber: Int, delayMs: Long)
}
```

---

## 🚫 Dead Letter Queue

For batches that fail permanently after max retries:

```kotlin
class DeadLetterQueue {
    fun addFailedBatch(batch: LogBatch, finalError: UploadError) {
        val deadLetter = DeadLetter(
            batchId = batch.id,
            originalTimestamp = batch.createdAt,
            failureTimestamp = System.currentTimeMillis(),
            error = finalError.toString(),
            retryCount = batch.uploadAttempts
        )
        
        storage.storeDeadLetter(deadLetter)
        notifyDelegate(deadLetter)
    }
    
    // Periodic cleanup or manual retry
    fun retryDeadLetters() {
        val deadLetters = storage.getDeadLetters()
        deadLetters.forEach { deadLetter ->
            if (shouldRetryDeadLetter(deadLetter)) {
                scheduleUpload(deadLetter.batchId)
                storage.removeDeadLetter(deadLetter.id)
            }
        }
    }
}
```

---

## 🧠 TL;DR for Interview Use

> "The Upload Manager is the SDK's reliable delivery system. It uses platform-specific background schedulers (WorkManager on Android, BGTaskScheduler on iOS) to upload log batches even when the app isn't running. It implements exponential backoff with jitter for retries, respects device constraints like battery and network type, and includes a dead letter queue for permanently failed batches. Think of it as a postal service that guarantees eventual delivery with smart retry logic and resource awareness."