# cycleresearch

Drop a few files into an existing repo, describe your problem, and let an AI agent work through it autonomously — running experiments, reasoning about results, and keeping a diary of what it tried.

Inspired by [Karpathy's autoresearch](https://github.com/karpathy/autoresearch) and [Donald Knuth's "Claude's Cycles"](https://www-cs-faculty.stanford.edu/~knuth/papers/claude-cycles.pdf): the idea of an idealized researcher cycling through hypotheses, experiments, and conclusions.

---

## How it works

The agent follows a simple loop:

1. Read `problem.md` and `diary.md`
2. Choose a step — either an **experiment** (write and run code) or a **reasoning** step (think something through in writing)
3. Create a folder for that step under `steps/`
4. Update `diary.md` before moving on
5. Repeat until it reaches a conclusion or hits the step budget

The agent maintains a live hypothesis list in `diary.md`, kills approaches that fail, and prefers understanding over brute-force search.

---

## Files

| File | Purpose |
|---|---|
| `CLAUDE.md` | Instructions Claude Code reads automatically |
| `AGENTS.md` | Instructions Codex reads automatically |
| `problem.md` | Your problem — fill this in before starting |
| `diary.md` | Running log of steps, findings, and hypotheses |
| `pyproject.toml` | Python dependencies (`uv`) |
| `Dockerfile.claude` | Defines the Docker image for Claude Code |
| `Dockerfile.codex` | Defines the Docker image for Codex |
| `.dockerignore` | Files to ignore when building either Docker image |
| `run_claude_linux.sh` | Launches Claude Code in Docker on Linux |
| `run_claude_mac.sh` | Launches Claude Code in Docker on macOS |
| `run_codex_linux.sh` | Launches Codex in Docker on Linux |

---

## Important notes

Having a clear evaluation method is key for this approach to work. The agent needs a way to know whether an experiment succeeded or failed so that it can update its hypotheses accordingly. This can be as simple as checking for specific output values, optimizing a benchmark, minimizing a loss, or passing a test case. The more specific and objective the evaluation criteria, the better the agent can learn from its experiments.

This approach generally works best with a capable reasoning model and a clear, testable problem specification.

Long context windows can consume credits quickly. It is usually better to restart sessions intermittently rather than keeping one very long-running thread.

## Three ways to run

### Option A — VS Code extension (easy, but interrupted)

Open the repo you want to work on in VS Code with the official Claude Code extension and log in to your Claude account. Edit `problem.md` to describe your problem, then start the agent in the dedicated chat UI.

The agent will work through the task but will ask for approval on many actions. This is the safest and most supervised option, and is useful for shorter sessions where you want to stay in the loop. It is not suitable for unattended work because the agent may pause and wait for input.

Choose the desired Claude model and effort setting in the extension before starting.

### Option B — Claude Code in Docker (fully autonomous)

This runs Claude Code with `--dangerously-skip-permissions`, allowing it to work without interruption. **Run this mode inside a Docker container, never directly on your machine.**

When permissions are skipped, the agent can do anything available to a normal process inside its environment: delete files, overwrite code, install packages, and make network requests. A container limits the exposed filesystem to the mounted project directory and any other resources you explicitly provide.

### Option C — Codex in Docker (fully autonomous)

The Codex launcher provides the equivalent autonomous workflow using a separate Docker image and a dedicated Codex configuration volume. The provided launcher currently targets Linux.

Its `run` mode uses Codex's approval-and-sandbox bypass inside the container. Docker therefore acts as the outer safety boundary. The launcher also offers a `safe` mode that keeps Codex's workspace sandbox enabled while disabling approval prompts.

### Security disclaimer

These container setups reduce risk, but they are not perfect security boundaries. Container escapes and configuration mistakes are possible.

Use a fresh clone or clean Git worktree, remove secrets such as `.env` files, and do not mount your Docker socket, SSH agent, home directory, cloud credentials, or unrelated files. The agent can freely modify everything inside the mounted repository.

---

## Docker setup

### Linux

```bash
sudo apt install docker.io
sudo usermod -aG docker "$USER"
# Log out and back in
```

### macOS

```bash
# Install Docker Desktop from:
# https://www.docker.com/products/docker-desktop/

# Or install it with Homebrew:
brew install --cask docker

# Launch Docker Desktop from Applications before using Docker commands.
```

Check that Docker works:

```bash
docker run hello-world
```

You only need to install Docker once.

---

## Prepare a working copy

Clone a fresh copy specifically for the agent. Do not use your normal working copy.

```bash
git clone <your-repo> your-repo-agent
cd your-repo-agent
rm -f .env
```

Copy the research-loop files into the repository:

```bash
cp /path/to/CLAUDE.md .
cp /path/to/AGENTS.md .
cp /path/to/problem.md .
cp /path/to/diary.md .
cp /path/to/pyproject.toml .
cp /path/to/.dockerignore .
```

Edit `problem.md` to describe the task as precisely as possible. Optionally set a step budget by editing the `BUDGET:` line at the top of `diary.md`.

---

## Run with Claude Code

Copy the Claude Dockerfile and the launcher for your operating system:

### Linux

```bash
cp /path/to/Dockerfile.claude .
cp /path/to/run_claude_linux.sh .
chmod +x run_claude_linux.sh

# First use: authenticate inside the container
./run_claude_linux.sh login

# Start an autonomous session
./run_claude_linux.sh run
```

### macOS

```bash
cp /path/to/Dockerfile.claude .
cp /path/to/run_claude_mac.sh .
chmod +x run_claude_mac.sh

# First use: authenticate inside the container
./run_claude_mac.sh login

# Start an autonomous session
./run_claude_mac.sh run
```

You can also open a shell in the same container environment:

```bash
./run_claude_linux.sh shell
# or:
./run_claude_mac.sh shell
```

When the `run` mode starts:

1. Docker builds the image from `Dockerfile.claude`
2. Docker mounts the current repository at `/workspace`
3. The container runs `uv sync`
4. Claude Code starts with:
   ```bash
   claude --model opus --effort max --dangerously-skip-permissions
   ```
5. Claude reads `CLAUDE.md`, `problem.md`, and `diary.md`, then works autonomously

Quit Claude normally to stop the session. The container exits, while changes to the mounted repository remain on your machine.

---

## Run with Codex

Copy the Codex Dockerfile and Linux launcher:

```bash
cp /path/to/Dockerfile.codex .
cp /path/to/run_codex_linux.sh .
chmod +x run_codex_linux.sh
```

Authenticate once:

```bash
./run_codex_linux.sh login
```

Start an interactive autonomous session:

```bash
./run_codex_linux.sh run
```

Run a single unattended task:

```bash
./run_codex_linux.sh exec \
  'Implement the next task in problem.md, run the tests, and update diary.md.'
```

Optional safer mode, which retains Codex's workspace sandbox inside Docker:

```bash
./run_codex_linux.sh safe
```

The Codex launcher builds from `Dockerfile.codex`, mounts the current repository at `/workspace`, and stores Codex authentication in its own Docker volume rather than mounting your host Codex configuration.

---

## Quickstart

### Claude Code on Linux

```bash
chmod +x run_claude_linux.sh
./run_claude_linux.sh login
./run_claude_linux.sh run
```

### Claude Code on macOS

```bash
chmod +x run_claude_mac.sh
./run_claude_mac.sh login
./run_claude_mac.sh run
```

### Codex on Linux

```bash
chmod +x run_codex_linux.sh
./run_codex_linux.sh login
./run_codex_linux.sh run
```
