#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-cycleresearch-codex}"
CONFIG_VOLUME="${CONFIG_VOLUME:-cycleresearch-codex-config}"
CODEX_VERSION="${CODEX_VERSION:-0.144.6}"
MODE="${1:-run}"

NPM_PREFIX="/home/agent/.codex/npm-global"
NPM_CACHE="/home/agent/.codex/npm-cache"
CONTAINER_PATH="${NPM_PREFIX}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

build_image() {
  echo "Building Docker image..."
  docker build \
    -f Dockerfile.codex \
    --build-arg "CODEX_VERSION=$CODEX_VERSION" \
    -t "$IMAGE_NAME" \
    .
}

run_container() {
  docker run -it --rm \
    --init \
    -e HOME=/home/agent \
    -e CODEX_HOME=/home/agent/.codex \
    -e XDG_CACHE_HOME=/home/agent/.cache \
    -e UV_CACHE_DIR=/home/agent/.cache/uv \
    -e UV_LINK_MODE=copy \
    -e NPM_CONFIG_PREFIX="$NPM_PREFIX" \
    -e NPM_CONFIG_CACHE="$NPM_CACHE" \
    -e PATH="$CONTAINER_PATH" \
    -v "$PWD":/workspace \
    -v "$CONFIG_VOLUME":/home/agent/.codex \
    -w /workspace \
    "$IMAGE_NAME" \
    bash -c "$1"
}

run_container_with_login_port() {
  docker run -it --rm \
    --init \
    -p 127.0.0.1:1455:1455 \
    -e HOME=/home/agent \
    -e CODEX_HOME=/home/agent/.codex \
    -e XDG_CACHE_HOME=/home/agent/.cache \
    -e UV_CACHE_DIR=/home/agent/.cache/uv \
    -e UV_LINK_MODE=copy \
    -e NPM_CONFIG_PREFIX="$NPM_PREFIX" \
    -e NPM_CONFIG_CACHE="$NPM_CACHE" \
    -e PATH="$CONTAINER_PATH" \
    -v "$PWD":/workspace \
    -v "$CONFIG_VOLUME":/home/agent/.codex \
    -w /workspace \
    "$IMAGE_NAME" \
    bash -lc "$1"
}

build_image
docker volume create "$CONFIG_VOLUME" >/dev/null

case "$MODE" in
  login)
    echo "Starting Codex device login..."
    run_container 'exec codex login --device-auth'
    ;;

  login-browser)
    echo "Starting Codex browser login with localhost:1455 exposed..."
    run_container_with_login_port 'exec codex login'
    ;;

  status)
    run_container 'exec codex login status'
    ;;

  version)
    run_container 'exec codex --version'
    ;;

  run)
    echo "Starting autonomous Codex session..."
    run_container 'uv sync && exec codex \
      --model gpt-5.6-sol \
      -C /workspace \
      --ask-for-approval never \
      --sandbox danger-full-access \
      --config '\''projects={"/workspace"={trust_level="trusted"}}'\'''
    ;;

  shell)
    run_container 'exec bash'
    ;;

  *)
    echo "Usage: ./run_codex_mac.sh [login|login-browser|status|version|run|shell]"
    exit 1
    ;;
esac
