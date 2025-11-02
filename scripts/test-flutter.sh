#!/usr/bin/env bash
set -euo pipefail

# Executes Flutter SDK acceptance scenarios with coverage aggregation.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ACCEPTANCE_DIR="$REPO_ROOT/tests/acceptance"
OUTPUT_DIR="$REPO_ROOT/coverage"

if ! command -v dart >/dev/null 2>&1; then
  echo "error: dart SDK not found on PATH" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

pushd "$ACCEPTANCE_DIR" >/dev/null
echo "Fetching acceptance harness dependencies..."
dart pub get >/dev/null
echo "Running acceptance scenarios..."
rm -rf coverage
mkdir -p coverage
if ! dart test --coverage=coverage/acceptance; then
  popd >/dev/null
  exit 1
fi
echo "Formatting acceptance coverage (lcov)..."
dart run coverage:format_coverage \
  --packages=.dart_tool/package_config.json \
  --report-on ../sdk/dart/lib \
  --lcov \
  --in coverage/acceptance \
  --out coverage/acceptance.lcov
popd >/dev/null

echo "Merging coverage reports..."
cat /dev/null > "$OUTPUT_DIR/lcov.info"
if [[ -f "$ACCEPTANCE_DIR/coverage/acceptance.lcov" ]]; then
  cat "$ACCEPTANCE_DIR/coverage/acceptance.lcov" >> "$OUTPUT_DIR/lcov.info"
fi
echo "Combined coverage written to $OUTPUT_DIR/lcov.info"
