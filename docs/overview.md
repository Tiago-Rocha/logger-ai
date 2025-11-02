# Cross-Platform Logger SDK Overview

This SDK provides a unified logging interface for iOS and Android so host apps can work with a single API surface. Core capabilities include:

- Structured event capture via `LogCollector` with automatic metadata enrichment
- Durable NDJSON persistence (crash-safe WAL) with idempotent record IDs
- Batch orchestration through `BatchManager` and policy-driven constraints
- Background scheduling with `UploadSchedule` plus cancellation support (`cancelScheduling`)
- Upload delivery through pluggable `UploadManager` implementations
- Delegate callbacks (`LoggerDelegate`) for collector errors, upload success/failure, and lifecycle events
- High-water mark propagation ensuring the same batch never re-uploads once acknowledged
