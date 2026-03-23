#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="cycleresearch-claude"

echo "Building Docker image..."
docker build -t "$IMAGE_NAME" .

echo "Starting container..."

docker run -it --rm \
  -v "$PWD":/workspace \
  -w /workspace \
  "$IMAGE_NAME" \
  bash -lc "uv sync && claude --model opus --effort max --dangerously-skip-permissions"
