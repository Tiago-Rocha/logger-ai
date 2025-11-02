# Flutter Logger SDK Implementation Plan

## Phase 1 – Foundation & Acceptance DSL *(Completed)*
- ✅ Custom Given/When/Then DSL harness lives under `tests/acceptance/` with a dedicated runner and shared world state.
- ✅ Acceptance scenarios for scheduling cadence and connectivity/power constraints are active; remaining flows stay disabled until their phases.
- ✅ Coverage aggregation is wired via `./scripts/test-flutter.sh`, and usage instructions now live in `AGENTS.md`.

## Phase 2 – Event Intake & Persistence *(Completed)*
- ✅ Persistence acceptance scenarios for rotation/high-water marks and collector flows (metadata propagation, validation, payload immutability, nested structures, delegate callbacks) are green.
- ✅ Unit/integration tests now cover collector, persistence, and batch manager foundations.
- ✅ File-backed storage handles metadata snapshots; groundwork ready for orchestration.

## Phase 3 – Batching & Upload Orchestration *(Completed)*
- ✅ Implemented batch manager policy limits and wired orchestration through `LoggerSdk`, including delegate notifications and high-water mark propagation.
- ✅ Acceptance scenarios for background execution, host outcomes, idempotency, and failure recovery are green.
- ✅ Upload manager contract supports per-batch high-water marks and failure reporting.

## Phase 4 – Background Scheduling & Delegates
- Build the scheduling facade that interprets host policies, enforces constraints, and handles cancellation cleanup.
- Complete delegate callback plumbing (foreground/background transitions, cancellation, retries) and ensure acceptance scenarios pass.
- Finalize public API exports, add samples/docs updates, and enforce ≥85% coverage on core modules using merged reports.

Each phase starts by enabling relevant acceptance scenarios (ATDD), then implements functionality through unit/integration TDD until the suite and coverage thresholds pass.
