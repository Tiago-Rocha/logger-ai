#!/usr/bin/env bash

# Wrapper that launches the official GitHub MCP server via Docker.
# Requirements:
#   - Docker CLI installed and able to run containers.
#   - GITHUB_PERSONAL_ACCESS_TOKEN environment variable set to a GitHub PAT
#     with the scopes required for your workflow (eg. repo, workflow).
# Optional environment variables:
#   - GITHUB_MCP_IMAGE  Override container image (default: ghcr.io/github/github-mcp-server:latest)
#   - GITHUB_TOOLSETS   Comma-separated toolsets to enable (default per server)

set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "error: docker CLI not found. Install Docker Desktop or the Docker CLI first." >&2
  exit 1
fi

TOKEN="${GITHUB_PERSONAL_ACCESS_TOKEN:-}"
if [[ -z "${TOKEN}" ]]; then
  echo "error: GITHUB_PERSONAL_ACCESS_TOKEN is not set. Export a GitHub PAT before starting the server." >&2
  exit 1
fi

IMAGE="${GITHUB_MCP_IMAGE:-ghcr.io/github/github-mcp-server:latest}"

docker_args=(
  run
  -i
  --rm
  -e "GITHUB_PERSONAL_ACCESS_TOKEN=${TOKEN}"
)

if [[ -n "${GITHUB_TOOLSETS:-}" ]]; then
  docker_args+=(-e "GITHUB_TOOLSETS=${GITHUB_TOOLSETS}")
fi

docker_args+=("${IMAGE}")

if [[ "$#" -gt 0 ]]; then
  docker_args+=("$@")
fi

exec docker "${docker_args[@]}"
