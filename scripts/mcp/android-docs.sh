#!/usr/bin/env bash

# Wrapper command that launches the Android SDK documentation MCP server.
# Usage:
#   ANDROID_DOCSET=/path/to/Android.docset scripts/mcp/android-docs.sh --stdio
# Environment variables:
#   ANDROID_DOCSET Path to the Android Dash/Zeal docset directory.
#   MCP_DOCS_BIN   Optional override for the mcp-docs executable (defaults to mcp-docs).

set -euo pipefail

DOCSET_PATH="${ANDROID_DOCSET:-}"
MCP_DOCS_BIN="${MCP_DOCS_BIN:-mcp-docs}"

if [[ -z "${DOCSET_PATH}" ]]; then
  echo "error: ANDROID_DOCSET is not set. Point it at the Android docset directory." >&2
  exit 1
fi

if [[ ! -d "${DOCSET_PATH}" ]]; then
  echo "error: '${DOCSET_PATH}' is not a directory. Verify your Android docset download." >&2
  exit 1
fi

if ! command -v "${MCP_DOCS_BIN}" >/dev/null 2>&1; then
  echo "error: '${MCP_DOCS_BIN}' binary not found. Install the mcp-docs server or set MCP_DOCS_BIN." >&2
  exit 1
fi

exec "${MCP_DOCS_BIN}" --docset "${DOCSET_PATH}" "$@"
