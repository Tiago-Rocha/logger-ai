# Repository Guidelines

## Project Structure & Module Organization
Keep reference material in `docs/` and refresh `CrossPlatform_Logger_SDK_Summary.md` whenever APIs shift. Implement the Kotlin library under `sdk/android` and the Swift package under `sdk/ios`. Shared protocol models, serialization helpers, and fixtures live in `shared/`. Platform-specific unit tests stay in `sdk/*/src/test`, while contract and end-to-end suites collect in `tests/`. Sample host apps for manual QA belong in `examples/` so they never leak into the shipping SDKs.

## Build, Test, and Development Commands
Run `./gradlew lintDebug testDebugUnitTest assemble` inside `sdk/android` to lint, test, and build the AAR. Inside `sdk/ios`, call `xcodebuild -scheme LoggerSDK -destination 'platform=iOS Simulator,name=iPhone 15' build` and follow with `xcodebuild test` for XCTest. Use `./scripts/test-all.sh` to fan out both stacks plus shared verifiers, and keep the script idempotent for CI.
For the Flutter SDK, run `dart test` inside `sdk/dart` for unit/integration coverage and `dart run tests/acceptance/bin/main.dart` to execute the acceptance DSL harness.

## Coding Style & Naming Conventions
Follow Kotlin coding conventions (4-space indent) on Android and Swift API Design Guidelines on iOS (`UpperCamelCase` types, `lowerCamelCase` members). Log event keys and `recordId` values use `snake_case` to match backend analytics. File names mirror the primary type (`LogUploadPolicy.swift`, `LogBatchPersistence.kt`). Run `./scripts/format.sh` before committing so `ktlint` and `swiftformat` apply canonical formatting.

## Testing Guidelines
Add JUnit 5 tests under `sdk/android/src/test`; add `src/androidTest` coverage only when WorkManager behaviors need instrumentation. iOS logic belongs in XCTest bundles at `sdk/ios/Tests`. Shared contract tests should deserialize fixtures from `shared/fixtures/` and assert parity across platforms. Target ≥85% coverage on core modules (`LogCollector`, `BatchManager`, `UploadManager`) and prioritize edge cases such as offline batches or exhausted backoff.

## Commit & Pull Request Guidelines
Use Conventional Commits (`feat:`, `fix:`, `chore:`) with imperative summaries and add ticket IDs via `Refs:` footers. Pull requests must outline the change, note host-app impact, and ship updated docs or fixtures when behavior shifts; include simulator or emulator logs for upload-path adjustments. Secure one review from the other platform owner and confirm Gradle, Xcode, and script checks before requesting merge.

## Security & Configuration Tips
Never hard-code credentials or endpoint secrets—read them from CI environment variables (`LOGGER_UPLOAD_URL`, `LOGGER_API_KEY`). Audit background upload scheduling so it honors documented constraints, and record WorkManager or BGTaskScheduler entitlement updates in `docs/permissions.md`. Rotate sample keys quarterly and scrub generated logs before committing so customer metadata never lands in git.

## MCP Tooling
Configure the Codex CLI agent with a Dart SDK documentation MCP so mobile developers can reach language references quickly. Add the server to your local agent config (for example `~/.config/codex/agents.yaml`) using a stanza similar to:

```yaml
mcpServers:
  - name: dart-docs
    command:
      - ./scripts/mcp/dart-docs.sh
      - --stdio
    env:
      DART_DOCSET: /Applications/Dash.app/Contents/SharedSupport/docsets/Dart.docset
```

Set `DART_DOCSET` to your local docset path (Zeal, Dash, or custom export) and restart the CLI so the Dart doc server registers. Adjust `MCP_DOCS_BIN` if you keep the `mcp-docs` executable somewhere else. Update this section if we standardize additional MCPs.
