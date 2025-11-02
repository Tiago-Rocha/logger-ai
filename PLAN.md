# Flutter Logger SDK Implementation Plan

## Phase 1 – Foundation & Acceptance DSL *(Completed)*
- ✅ Custom Given/When/Then DSL harness lives under `tests/acceptance/` with a dedicated runner and shared world state.
- ✅ Acceptance scenarios for scheduling cadence and connectivity/power constraints are active; remaining flows stay disabled until their phases.
- ✅ Coverage aggregation is wired via `./scripts/test-flutter.sh`, and usage instructions now live in `AGENTS.md`.

## Phase 2 – Event Intake & Persistence
- Flesh out domain models and the collector using unit tests derived from acceptance steps.
- Implement `FileLogPersistence` with rotation and metadata management, validated by unit/integration tests.
- Update acceptance scenarios to pass for persistence-focused behaviors and ensure coverage captures these paths.

## Phase 3 – Batching & Upload Orchestration
- TDD the batch manager to respect policy thresholds and reuse across foreground/background runs.
- Implement the upload manager with retry/backoff and delegate notifications, satisfying acceptance expectations.
- Surface configuration inputs via `LoggerConfig`/`LogUploadPolicy` aligned with the DSL scenarios.

## Phase 4 – Background Scheduling & Delegates
- Build the scheduling facade that interprets host policies, enforces constraints, and handles cancellation cleanup.
- Complete delegate callback plumbing and ensure all acceptance scenarios pass.
- Finalize public API exports, add samples/docs updates, and enforce ≥85% coverage on core modules using merged reports.

Each phase starts by enabling relevant acceptance scenarios (ATDD), then implements functionality through unit/integration TDD until the suite and coverage thresholds pass.
