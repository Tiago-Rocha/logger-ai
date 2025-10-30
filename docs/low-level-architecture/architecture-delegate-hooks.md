# 🔗 Logger SDK Delegate & Hooks Architecture

This document explains how the **Delegate & Hooks** system provides extensibility
and observability for the Logger SDK, allowing host applications to customize
behavior and respond to important events throughout the logging lifecycle.

---

## 🧩 Concept Overview

The **Delegate & Hooks** system acts as the SDK's extension and notification mechanism.
It provides:

1. **Event notifications** for key lifecycle moments
2. **Customization points** for SDK behavior
3. **Error handling** and recovery opportunities
4. **Monitoring hooks** for observability and debugging

> ✅ **Key goal:** Enable host applications to integrate deeply with the SDK while maintaining clean separation of concerns.

---

## 🏗️ Component Structure

```
┌──────────────────────── Delegate & Hooks System ───────────────────────┐
│                                                                        │
│  ┌─────────────────┐    ┌─────────────────┐    ┌───────────────────┐  │
│  │   Event Hub     │───▶│   Delegate      │───▶│   Hook Registry   │  │
│  │                 │    │   Interface     │    │                   │  │
│  │ • Event queue   │    │ • Callbacks     │    │ • Pre/Post hooks  │  │
│  │ • Async dispatch│    │ • Error         │    │ • Middleware      │  │
│  │ • Filtering     │    │   handling      │    │   chain           │  │
│  │ • Throttling    │    │ • Configuration │    │ • Plugin system   │  │
│  └─────────────────┘    └─────────────────┘    └───────────────────┘  │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 📡 Event Types & Lifecycle

### Core Logging Events
```kotlin
interface LoggerDelegate {
    // Log Collection Events
    fun onLogReceived(logEvent: LogEvent)
    fun onLogValidationFailed(rawLog: RawLog, reason: String)
    fun onLogEnriched(originalLog: LogEvent, enrichedLog: EnrichedLogEvent)
    
    // Batch Management Events  
    fun onBatchCreated(batch: LogBatch)
    fun onBatchCompressed(batchId: String, originalSize: Long, compressedSize: Long)
    fun onBatchReady(batch: LogBatch)
    
    // Upload Events
    fun onUploadStarted(batchId: String, attemptNumber: Int)
    fun onUploadProgress(batchId: String, bytesTransferred: Long, totalBytes: Long)
    fun onUploadCompleted(batchId: String, response: UploadResponse)
    fun onUploadFailed(batchId: String, error: UploadError, willRetry: Boolean)
    fun onUploadRetry(batchId: String, attemptNumber: Int, delayMs: Long)
    
    // System Events
    fun onSDKInitialized(config: LoggerConfig)
    fun onConfigurationChanged(oldConfig: LoggerConfig, newConfig: LoggerConfig)
    fun onStorageCleanup(deletedFiles: List<String>, freedBytes: Long)
    fun onError(error: LoggerError, context: Map<String, Any>)
}
```

### Event Flow Diagram
```
Logger.log() called
   ↓
onLogReceived() ─────┐ (Validation fails)
   ↓                ├─▶ onLogValidationFailed()
onLogEnriched()     │
   ↓                │
[Persistence Layer] │
   ↓                │
onBatchCreated() ───┘
   ↓
onBatchCompressed()
   ↓
onBatchReady()
   ↓
onUploadStarted()
   ↓
onUploadProgress() (multiple calls)
   ↓
onUploadCompleted() ─┐ (Success)
                    │
onUploadFailed() ────┘ (Failure)
   ↓
onUploadRetry() (if retrying)
```

---

## 🎣 Hook System

### Pre/Post Processing Hooks
```swift
protocol LoggerHooks {
    // Pre-processing (can modify or reject)
    func preLogCollection(_ logEvent: inout LogEvent) -> Bool
    func preBatchCreation(_ logs: inout [EnrichedLogEvent]) -> Bool  
    func preUpload(_ batch: inout LogBatch) -> Bool
    
    // Post-processing (notification only)
    func postLogCollection(_ logEvent: LogEvent)
    func postBatchCreation(_ batch: LogBatch)
    func postUpload(_ batch: LogBatch, result: UploadResult)
}
```

### Hook Chain Example
```kotlin
class HookChain<T> {
    private val hooks = mutableListOf<Hook<T>>()
    
    fun addHook(hook: Hook<T>) {
        hooks.add(hook)
    }
    
    fun execute(data: T): HookResult<T> {
        var currentData = data
        
        for (hook in hooks) {
            val result = hook.process(currentData)
            when (result) {
                is HookResult.Continue -> currentData = result.data
                is HookResult.Stop -> return result
                is HookResult.Reject -> return result
            }
        }
        
        return HookResult.Continue(currentData)
    }
}
```

---

## 🔧 Customization Points

### Log Filtering Hook
```swift
class PiiFilterHook: LoggerHook {
    private let sensitiveFields = ["password", "ssn", "creditCard"]
    
    func preLogCollection(_ logEvent: inout LogEvent) -> Bool {
        // Remove sensitive fields from log data
        if var data = logEvent.data {
            for field in sensitiveFields {
                data.removeValue(forKey: field)
            }
            logEvent.data = data
        }
        return true // Continue processing
    }
}
```

### Custom Enrichment Hook
```kotlin
class UserContextHook : LoggerHook {
    fun preLogCollection(logEvent: LogEvent): HookResult<LogEvent> {
        val enrichedEvent = logEvent.copy(
            metadata = logEvent.metadata + mapOf(
                "userId" to UserManager.getCurrentUserId(),
                "userTier" to UserManager.getCurrentUserTier(),
                "experimentGroups" to ExperimentManager.getActiveGroups()
            )
        )
        return HookResult.Continue(enrichedEvent)
    }
}
```

### Upload Modification Hook
```swift
class CompressionHook: LoggerHook {
    func preUpload(_ batch: inout LogBatch) -> Bool {
        if batch.sizeBytes > 1024 * 1024 { // 1MB
            batch.data = try? compress(batch.data)
            batch.headers["Content-Encoding"] = "gzip"
        }
        return true
    }
}
```

---

## 📊 Monitoring & Observability

### Analytics Integration
```kotlin
class AnalyticsDelegate : LoggerDelegate {
    private val analytics = FirebaseAnalytics.getInstance()
    
    override fun onUploadCompleted(batchId: String, response: UploadResponse) {
        analytics.logEvent("logger_upload_success", Bundle().apply {
            putString("batch_id", batchId)
            putLong("batch_size", response.batchSize)
            putLong("upload_duration_ms", response.uploadDuration)
        })
    }
    
    override fun onUploadFailed(batchId: String, error: UploadError, willRetry: Boolean) {
        analytics.logEvent("logger_upload_failed", Bundle().apply {
            putString("batch_id", batchId)
            putString("error_type", error.javaClass.simpleName)
            putBoolean("will_retry", willRetry)
        })
    }
}
```

### Performance Monitoring
```swift
class PerformanceMonitoringDelegate: LoggerDelegate {
    func onBatchCreated(_ batch: LogBatch) {
        let metrics = [
            "batch_size_bytes": batch.sizeBytes,
            "log_count": batch.logCount,
            "compression_ratio": batch.compressionRatio
        ]
        
        Performance.shared.recordEvent("logger_batch_created", attributes: metrics)
    }
    
    func onUploadCompleted(_ batchId: String, response: UploadResponse) {
        let uploadTime = response.endTime - response.startTime
        Performance.shared.recordDuration("logger_upload_duration", duration: uploadTime)
    }
}
```

---

## 🚨 Error Handling & Recovery

### Error Recovery Delegate
```kotlin
class ErrorRecoveryDelegate : LoggerDelegate {
    override fun onUploadFailed(batchId: String, error: UploadError, willRetry: Boolean) {
        when (error) {
            is AuthenticationError -> {
                // Refresh auth token
                AuthManager.refreshToken { newToken ->
                    Logger.updateConfig { it.copy(apiToken = newToken) }
                }
            }
            is NetworkError -> {
                // Switch to cellular if on WiFi
                if (NetworkManager.isWiFiConnected() && !willRetry) {
                    Logger.updateConfig { 
                        it.copy(uploadConstraints = it.uploadConstraints.copy(requireWiFi = false))
                    }
                }
            }
            is ServerError -> {
                // Maybe switch to backup endpoint
                if (error.statusCode >= 500) {
                    Logger.updateConfig { 
                        it.copy(uploadEndpoint = BACKUP_ENDPOINT)
                    }
                }
            }
        }
    }
}
```

---

## 🔌 Plugin System

### Plugin Interface
```swift
protocol LoggerPlugin {
    var name: String { get }
    var version: String { get }
    
    func initialize(with config: PluginConfig)
    func onEvent(_ event: LoggerEvent)
    func onShutdown()
}

class PluginManager {
    private var plugins: [LoggerPlugin] = []
    
    func registerPlugin(_ plugin: LoggerPlugin) {
        plugins.append(plugin)
        plugin.initialize(with: getPluginConfig(for: plugin))
    }
    
    func notifyPlugins(of event: LoggerEvent) {
        plugins.forEach { $0.onEvent(event) }
    }
}
```

### Example Plugin: Crash Reporter Integration
```kotlin
class CrashReporterPlugin : LoggerPlugin {
    override val name = "CrashReporter"
    override val version = "1.0.0"
    
    override fun onEvent(event: LoggerEvent) {
        when (event) {
            is LogEvent -> {
                if (event.level == LogLevel.ERROR || event.level == LogLevel.FATAL) {
                    Crashlytics.log("Logger: ${event.message}")
                    event.data?.let { data ->
                        Crashlytics.setCustomKeys(data)
                    }
                }
            }
            is UploadFailedEvent -> {
                Crashlytics.recordException(
                    LoggerUploadException(event.error, event.batchId)
                )
            }
        }
    }
}
```

---

## ⚙️ Configuration

### Delegate Registration
```swift
// iOS
Logger.shared.delegate = MyLoggerDelegate()
Logger.shared.addHook(PiiFilterHook())
Logger.shared.addHook(UserContextHook())
Logger.shared.registerPlugin(CrashReporterPlugin())
```

```kotlin
// Android
Logger.setDelegate(MyLoggerDelegate())
Logger.addHook(PiiFilterHook())
Logger.addHook(UserContextHook())  
Logger.registerPlugin(CrashReporterPlugin())
```

### Event Filtering
```json
{
  "delegates": {
    "eventFiltering": {
      "enabled": true,
      "includedEvents": ["onUploadCompleted", "onUploadFailed", "onError"],
      "excludedEvents": ["onLogReceived", "onUploadProgress"],
      "throttling": {
        "onUploadProgress": "100ms", // Max once per 100ms
        "onLogReceived": "1s"        // Max once per second
      }
    }
  }
}
```

---

## 🧠 TL;DR for Interview Use

> "The Delegate & Hooks system is the SDK's extension point. It's like a pub-sub system that notifies the host app about important events (uploads, errors, etc.) and provides hooks to customize behavior (filter logs, modify uploads, add metadata). Think of it as middleware for logging - you can inject custom logic at any point in the pipeline. This enables powerful integrations with analytics, crash reporting, and custom business logic while keeping the core SDK focused and testable."