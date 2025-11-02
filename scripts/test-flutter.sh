#!/usr/bin/env bash
set -euo pipefail

# Runs unit/integration tests for the Flutter SDK and the acceptance DSL harness.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK_DIR="$REPO_ROOT/sdk/dart"
ACCEPTANCE_DIR="$REPO_ROOT/tests/acceptance"

pushd "$SDK_DIR" >/dev/null
if ! command -v dart >/dev/null 2>&1; then
  echo "error: dart SDK not found on PATH" >&2
  exit 1
fi

echo "Running Flutter SDK unit tests..."
dart test --coverage=coverage/unit 
popd >/dev/null

pushd "$ACCEPTANCE_DIR" >/dev/null
echo "Fetching acceptance harness dependencies..."
dart pub get >/dev/null
echo "Running acceptance scenarios..."
dart run ./bin/main.dart
popd >/dev/null

echo "Merging coverage reports..."
# Placeholder for future coverage aggregation logic.

