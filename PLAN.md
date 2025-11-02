# Flutter Logger SDK Implementation Plan

## Phase 1 – Foundation & Acceptance DSL *(Completed)*
- ✅ Custom Given/When/Then DSL harness lives under `tests/acceptance/` with a dedicated runner and shared world state.
- ✅ Acceptance scenarios for scheduling cadence and connectivity/power constraints are active; remaining flows stay disabled until their phases.
- ✅ Coverage aggregation is wired via `./scripts/test-flutter.sh`, and usage instructions now live in `AGENTS.md`.

## Phase 2 – Event Intake & Persistence
- In progress: persistence acceptance scenarios for rotation/high-water marks and collector flows (metadata propagation, validation, payload immutability, nested structures, delegate callbacks) are green; file-backed storage handles metadata snapshots.
- Next: begin layering unit/integration tests for collector/persistence components and address remaining behaviours (batch manager integration, error logging) before transitioning to Phase 3.
- Update unit/integration suites to enforce ≥85% coverage once intake pipeline unit tests are in place.

## Phase 3 – Batching & Upload Orchestration
- In progress: batch manager policy limits and upload orchestration scenarios (background execution, host notifications, retry after failure) are now green across acceptance and unit tests.
- Next: extend the upload path with retry/backoff strategy and integrate high-water mark propagation/documentation.
- Ensure configuration inputs remain surfaced via `LoggerConfig`/`LogUploadPolicy` as new behaviours land.

## Phase 4 – Background Scheduling & Delegates
- Build the scheduling facade that interprets host policies, enforces constraints, and handles cancellation cleanup.
- Complete delegate callback plumbing and ensure all acceptance scenarios pass.
- Finalize public API exports, add samples/docs updates, and enforce ≥85% coverage on core modules using merged reports.

Each phase starts by enabling relevant acceptance scenarios (ATDD), then implements functionality through unit/integration TDD until the suite and coverage thresholds pass.
