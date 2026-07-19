#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$PWD}"
DOCKERFILE="${DOCKERFILE:-$SCRIPT_DIR/Dockerfile.codex}"
IMAGE_NAME="${IMAGE_NAME:-cycleresearch-codex}"
CONFIG_VOLUME="${CONFIG_VOLUME:-cycleresearch-codex-home}"
CACHE_VOLUME="${CACHE_VOLUME:-cycleresearch-codex-cache}"
CODEX_VERSION="${CODEX_VERSION:-0.144.6}"
MODE="${1:-run}"
shift || true

if [[ ! -f "$DOCKERFILE" ]]; then
    echo "Missing Dockerfile: $DOCKERFILE" >&2
    exit 1
fi

PROJECT_DIR="$(cd -- "$PROJECT_DIR" && pwd)"

if [[ "${NO_BUILD:-0}" != "1" ]]; then
    echo "Building Codex image (${CODEX_VERSION})..."
    docker build \
        --file "$DOCKERFILE" \
        --build-arg "USER_ID=$(id -u)" \
        --build-arg "GROUP_ID=$(id -g)" \
        --build-arg "CODEX_VERSION=$CODEX_VERSION" \
        --tag "$IMAGE_NAME" \
        "$SCRIPT_DIR"
fi

docker volume create "$CONFIG_VOLUME" >/dev/null
docker volume create "$CACHE_VOLUME" >/dev/null

DOCKER_COMMON=(
    docker run --rm
    --init
    --hostname codex-agent
    --user "$(id -u):$(id -g)"
    --read-only
    --cap-drop=ALL
    --security-opt=no-new-privileges:true
    --pids-limit "${PIDS_LIMIT:-1024}"
    --tmpfs /tmp:rw,nosuid,nodev,size="${TMP_SIZE:-1g}"
    --tmpfs /run:rw,nosuid,nodev,size=64m
    --mount "type=bind,src=${PROJECT_DIR},dst=/workspace"
    --mount "type=volume,src=${CONFIG_VOLUME},dst=/home/agent/.codex"
    --mount "type=volume,src=${CACHE_VOLUME},dst=/home/agent/.cache"
    --workdir /workspace
    --env HOME=/home/agent
    --env CODEX_HOME=/home/agent/.codex
    --env XDG_CACHE_HOME=/home/agent/.cache
    --env UV_CACHE_DIR=/home/agent/.cache/uv
    --env UV_LINK_MODE=copy
)

# Optional resource limits. Leave unset to use Docker defaults.
if [[ -n "${MEMORY_LIMIT:-}" ]]; then
    DOCKER_COMMON+=(--memory "$MEMORY_LIMIT")
fi
if [[ -n "${CPU_LIMIT:-}" ]]; then
    DOCKER_COMMON+=(--cpus "$CPU_LIMIT")
fi

run_interactive() {
    "${DOCKER_COMMON[@]}" -it "$IMAGE_NAME" "$@"
}

run_noninteractive() {
    "${DOCKER_COMMON[@]}" "$IMAGE_NAME" "$@"
}

sync_project() {
    if [[ "${SKIP_UV_SYNC:-0}" == "1" ]]; then
        return
    fi
    if [[ -f "$PROJECT_DIR/pyproject.toml" ]]; then
        echo "Synchronising Python environment with uv..."
        run_noninteractive uv sync
    fi
}

CODEX_COMMON_FLAGS=(
    -C /workspace
    # Avoid the first-run directory trust prompt in disposable containers.
    # This trusts project-level Codex configuration found under /workspace.
    --config 'projects={"/workspace"={trust_level="trusted"}}'
)
if [[ -n "${CODEX_MODEL:-}" ]]; then
    CODEX_COMMON_FLAGS+=(--model "$CODEX_MODEL")
fi
if [[ -n "${CODEX_REASONING_EFFORT:-}" ]]; then
    CODEX_COMMON_FLAGS+=(
        --config "model_reasoning_effort=\"${CODEX_REASONING_EFFORT}\""
    )
fi
if [[ "${CODEX_SEARCH:-0}" == "1" ]]; then
    CODEX_COMMON_FLAGS+=(--search)
fi

# External-sandbox mode: no Codex prompts and no Codex-internal shell sandbox.
YOLO_FLAGS=(--dangerously-bypass-approvals-and-sandbox)

# Defence-in-depth mode: no prompts, but model-generated commands remain confined
# by Codex to the mounted workspace. This can block package downloads or other
# commands that require network access.
SAFE_FLAGS=(--ask-for-approval never --sandbox workspace-write)

case "$MODE" in
    login)
        echo "Starting device-code login. Credentials stay in Docker volume: $CONFIG_VOLUME"
        run_interactive codex login --device-auth
        ;;

    login-browser)
        echo "Starting browser callback login. Device-code login is usually easier in Docker."
        run_interactive codex login
        ;;

    status)
        run_noninteractive codex login status
        ;;

    doctor)
        run_interactive codex doctor
        ;;

    version)
        run_noninteractive codex --version
        ;;

    run)
        sync_project
        echo "Starting autonomous Codex session inside the external Docker sandbox..."
        run_interactive codex "${CODEX_COMMON_FLAGS[@]}" "${YOLO_FLAGS[@]}"
        ;;

    safe)
        sync_project
        echo "Starting no-confirmation Codex session with Codex workspace sandboxing enabled..."
        run_interactive codex "${CODEX_COMMON_FLAGS[@]}" "${SAFE_FLAGS[@]}"
        ;;

    exec)
        if [[ "$#" -eq 0 ]]; then
            echo "Usage: $0 exec 'prompt for Codex'" >&2
            exit 1
        fi
        sync_project
        PROMPT="$*"
        run_noninteractive codex \
            "${CODEX_COMMON_FLAGS[@]}" \
            "${YOLO_FLAGS[@]}" \
            exec --skip-git-repo-check "$PROMPT"
        ;;

    exec-safe)
        if [[ "$#" -eq 0 ]]; then
            echo "Usage: $0 exec-safe 'prompt for Codex'" >&2
            exit 1
        fi
        sync_project
        PROMPT="$*"
        run_noninteractive codex \
            "${CODEX_COMMON_FLAGS[@]}" \
            "${SAFE_FLAGS[@]}" \
            exec --skip-git-repo-check "$PROMPT"
        ;;

    shell)
        run_interactive bash
        ;;

    *)
        cat >&2 <<USAGE
Usage: $0 [login|login-browser|status|doctor|version|run|safe|exec|exec-safe|shell]

  login         Sign in using device-code authentication.
  run           Interactive autonomous mode; Docker is the external sandbox.
  safe          Interactive no-confirmation mode with Codex workspace sandboxing.
  exec PROMPT   Non-interactive autonomous task.
  exec-safe     Non-interactive task with Codex workspace sandboxing.
  shell         Open a shell in the hardened container.

Environment overrides:
  CODEX_VERSION=0.144.6   Codex npm version to build.
  CODEX_MODEL=...         Optional model override.
  CODEX_REASONING_EFFORT=high|xhigh
  CODEX_SEARCH=1          Enable Codex's native web-search tool.
  SKIP_UV_SYNC=1          Do not run uv sync before agent sessions.
  NO_BUILD=1              Reuse the already-built image.
  PROJECT_DIR=/path       Mount a project other than the current directory.
  MEMORY_LIMIT=16g        Optional Docker memory limit.
  CPU_LIMIT=8             Optional Docker CPU limit.
USAGE
        exit 1
        ;;
esac
