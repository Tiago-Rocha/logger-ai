# `LogUploadPolicy` Model

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
