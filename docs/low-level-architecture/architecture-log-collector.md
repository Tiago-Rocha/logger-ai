# 📝 Logger SDK Log Collector Architecture

This document explains how the **Log Collector** component handles incoming log events,
formats them with metadata, and prepares them for persistence.

---

## 🧩 Concept Overview

The **Log Collector** is the entry point for all logging operations in the SDK.
When `Logger.log()` is called, it:

1. **Validates** the incoming log data
2. **Enriches** it with contextual metadata
3. **Serializes** it into a standardized format
4. **Forwards** it to the Persistence layer

> ✅ **Key goal:** Transform raw log calls into structured, enriched log events ready for storage.

---

## 🏗️ Component Structure

```
┌─────────────────────────── Log Collector ───────────────────────────┐
│                                                                    │
│  ┌──────────────┐    ┌─────────────────┐    ┌─────────────────┐    │
│  │   Validator  │───▶│   Enricher      │───▶│   Serializer    │    │
│  │              │    │                 │    │                 │    │
│  │ • Required   │    │ • Timestamp     │    │ • JSON format   │    │
│  │   fields     │    │ • Record ID     │    │ • Schema        │    │
│  │ • Data types │    │ • Session info  │    │   validation    │    │
│  │ • Size limits│    │ • Device info   │    │ • Compression   │    │
│  └──────────────┘    └─────────────────┘    └─────────────────┘    │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

---

## 📊 Data Flow

```
Logger.log("user_action", {userId: "123", action: "click"})
   ↓
┌─────────────────── Validation ──────────────────┐
│ ✅ Message is string                           │
│ ✅ Payload is valid JSON                       │
│ ✅ Size < max limit (e.g., 64KB)               │
│ ✅ No sensitive data patterns                  │
└─────────────────────────────────────────────────┘
   ↓
┌─────────────────── Enrichment ──────────────────┐
│ + recordId: "01JBQR7X8P9K2M3N4Q5R6S7T8V"       │
│ + timestamp: 1730200000123                     │
│ + level: "info"                                │
│ + sessionId: "sess_abc123"                     │
│ + appVersion: "1.2.3"                          │
│ + platform: "iOS" / "Android"                 │
│ + userId: <if configured>                      │
└─────────────────────────────────────────────────┘
   ↓
┌─────────────────── Serialization ───────────────┐
│ {                                              │
│   "id": "01JBQR7X8P9K2M3N4Q5R6S7T8V",          │
│   "ts": 1730200000123,                         │
│   "lvl": "info",                               │
│   "msg": "user_action",                        │
│   "data": {                                    │
│     "userId": "123",                           │
│     "action": "click"                          │
│   },                                           │
│   "meta": {                                    │
│     "sessionId": "sess_abc123",                │
│     "appVersion": "1.2.3",                     │
│     "platform": "iOS"                          │
│   }                                            │
│ }                                              │
└─────────────────────────────────────────────────┘
   ↓
Forward to Persistence Layer
```

---

## 🔧 Key Components

### 1. Validator

**Purpose:** Ensure incoming log data meets SDK requirements

**Responsibilities:**
- Check required fields (message, level)
- Validate data types and structure
- Enforce size limits (prevent memory issues)
- Filter sensitive data (PII, credentials)
- Apply rate limiting if configured

**Example validation rules:**
```kotlin
// Android
class LogValidator {
    fun validate(message: String, data: Map<String, Any>?): ValidationResult {
        if (message.isBlank()) return ValidationResult.Error("Message required")
        if (message.length > MAX_MESSAGE_LENGTH) return ValidationResult.Error("Message too long")
        if (data?.let { JsonUtils.serialize(it).length } ?: 0 > MAX_DATA_SIZE) {
            return ValidationResult.Error("Data payload too large")
        }
        return ValidationResult.Valid
    }
}
```

### 2. Enricher

**Purpose:** Add contextual metadata to logs

**Automatic enrichment:**
- **Record ID:** Unique identifier using ULID/UUID
- **Timestamp:** High-precision UTC timestamp
- **Session ID:** Current app session identifier
- **Device metadata:** OS version, device model, app version
- **User context:** User ID (if configured and consented)

**Platform-specific data:**
```swift
// iOS
struct LogEnricher {
    func enrich(_ logEvent: LogEvent) -> EnrichedLogEvent {
        return EnrichedLogEvent(
            id: ULID.generate(),
            timestamp: Date().timeIntervalSince1970 * 1000,
            level: logEvent.level,
            message: logEvent.message,
            data: logEvent.data,
            metadata: Metadata(
                sessionId: SessionManager.shared.currentSessionId,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                platform: "iOS",
                osVersion: UIDevice.current.systemVersion,
                deviceModel: UIDevice.current.model
            )
        )
    }
}
```

### 3. Serializer

**Purpose:** Convert enriched logs into storage-ready format

**Features:**
- JSON serialization with consistent schema
- Optional compression (gzip/deflate)
- Field name normalization (snake_case)
- Error handling for serialization failures

---

## 🎯 Configuration Options

The Log Collector can be configured through `LogCollectorConfig`:

```json
{
  "maxMessageLength": 1024,
  "maxDataSize": 65536,
  "enablePiiFiltering": true,
  "rateLimitPerSecond": 100,
  "enrichmentLevel": "full", // "minimal", "standard", "full"
  "compressionEnabled": true,
  "sensitiveFields": ["password", "token", "secret"]
}
```

---

## 🚦 Error Handling

The Log Collector implements graceful error handling:

1. **Validation Errors:** Log dropped, error callback invoked
2. **Enrichment Errors:** Partial enrichment, warning logged
3. **Serialization Errors:** Fallback to minimal log format
4. **System Errors:** Retry with exponential backoff

```kotlin
// Example error handling
try {
    val enrichedLog = enricher.enrich(rawLog)
    val serializedLog = serializer.serialize(enrichedLog)
    persistenceLayer.store(serializedLog)
} catch (ValidationException e) {
    delegate?.onLogRejected(rawLog, e.reason)
} catch (SerializationException e) {
    // Try minimal format
    val minimalLog = createMinimalLog(rawLog)
    persistenceLayer.store(minimalLog)
}
```

---

## 📊 Performance Considerations

- **Lazy evaluation:** Metadata enrichment only when needed
- **Object pooling:** Reuse serialization buffers
- **Background processing:** Async enrichment for heavy operations
- **Memory management:** Clear references after processing

---

## 🧠 TL;DR for Interview Use

> "The Log Collector is the SDK's front door. It validates incoming logs, enriches them with contextual metadata like timestamps and session info, then serializes them to JSON. It handles errors gracefully and can be configured for different use cases. Think of it as a pipeline that transforms raw `Logger.log()` calls into structured, storage-ready events."