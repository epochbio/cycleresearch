# cycleresearch

Drop a few files into an existing repo, describe your problem, and let an AI agent work through it autonomously — running experiments, reasoning about results, and keeping a diary of what it tried.

Inspired by [Karpathy's autoresearch](https://github.com/karpathy/autoresearch)  and [Donald Knuth's "Claudes Cycles"](https://www-cs-faculty.stanford.edu/~knuth/papers/claude-cycles.pdf): the idea of an idealized researcher cycling through hypotheses, experiments, and conclusions.

---

## How it works

The agent follows a simple loop:

1. Read `problem.md` and `diary.md`
2. Choose a step — either an **experiment** (write and run code) or a **reasoning** (think something through in writing)
3. Create a folder for that step under `steps/`
4. Update `diary.md` before moving on
5. Repeat until it reaches a conclusion or hits the step budget

The agent maintains a live hypothesis list in `diary.md`, kills approaches that fail, and prefers understanding over brute-force search.

---

## Files

| File | Purpose |
|---|---|
| `CLAUDE.md` | Instructions the agent reads automatically |
| `problem.md` | Your problem — fill this in before starting |
| `diary.md` | Running log of steps, findings, and hypotheses |
| `pyproject.toml` | Python dependencies (`uv`) |
| `Dockerfile` | Defines the Docker image for the agent |
| `.dockerignore` | Files to ignore when building the Docker image |
| `run_agent.sh` | Helper script to launch the Docker container and start the agent |

---

## Important notes
I find that this approach works best using frontier models in "thinking mode". As of March 2026 this is Claude Opus with the Max effort setting.

Long context windows can consume credits quickly. It is usually better to restart sessions intermittently (and at the latest when you hit the Claude usage cap), rather than keeping one very long-running thread.

## Two ways to run

### Option A — VSCode extension (easy, but interrupted)

Open the repo you want to work on in VSCode with the official Claude Code extension (and having logged into your Claude Pro account). Edit the `problem.md` file to describe your problem. Then start the agent in the dedicated chat UI. The agent will get working but will ask for approval on most actions. This is the safest and most supervised option — good for shorter sessions where you want to stay in the loop; but you cannot leave it running unattended because it will pause and wait for your input.

You will need to change the model to "Claude Opus" and the effort to "Max" manually in the extension settings before starting the session, to get the best results.


### Option B — Command line with `--dangerously-skip-permissions` (fully autonomous)

This lets the agent run without any interruption. **It must be run inside a Docker container — never directly on your machine.** When permissions are skipped, the agent can do anything a normal process can: delete files, overwrite code, install packages, and make network requests. Without a container, that means your entire home directory, SSH keys, credentials, and any mounted drives are in scope. A container limits the blast radius to just the repo folder, while still allowing the internet access the agent needs.

**Security disclaimer:** this container setup reduces risk, but it is not 100% airtight. Container escapes and misconfiguration risks exist. Do your own research, validate the setup for your environment, and do not rely on this implementation alone as a complete safety boundary.

#### Setup (one time)

**Linux:**
```bash
sudo apt install docker.io
sudo usermod -aG docker $USER
# Log out and back in
```

**Mac:**
```bash
# Install Docker Desktop from https://www.docker.com/products/docker-desktop/
# Or via Homebrew:
brew install --cask docker
# Then launch Docker Desktop from Applications — it must be running before using docker commands
```

To check if Docker is installed and working, run:
```bash
docker run hello-world
```

That's it for setup. You only need to do this once.

#### Per session

Clone a fresh copy specifically for the agent to work in — do not use your normal working copy. This way the agent has full access to your codebase, but any mistakes are isolated to the clone.

Next you will need to add the provided files into your repo. Copy `CLAUDE.md`, `problem.md`, `diary.md`, and `pyproject.toml` into the root of your repo. These govern how the agent behaves. Edit `problem.md` to describe your problem with as much detail as possible. Next add the files `Dockerfile`, `.dockerignore`, and `run_agent.sh` files as well. These define the Docker image (the environment the agent runs in) and a helper script to launch the container and start the agent.


```bash
# Clone a fresh copy of your repo — the agent will work here, not on your original
git clone <your-repo> your-repo-agent
cd your-repo-agent
rm -f .env   # remove any secrets before running

# Copy the necessary files into your repo
cp /path/to/CLAUDE.md .
cp /path/to/problem.md .
cp /path/to/diary.md .
cp /path/to/pyproject.toml .
cp /path/to/Dockerfile .
cp /path/to/.dockerignore .
cp /path/to/run_agent.sh .

# Make sure the helper script is executable
chmod +x run_agent.sh

# First run only: log into Claude inside the container
./run_agent.sh --login

# After login completes, exit that Claude session, then re-run normally
./run_agent.sh
```

On first use, `--login` is only for authentication. The actual autonomous run should be started without `--login`, because Claude should run with the normal flags from the script.

What happens when you run `./run_agent.sh`:

1. Docker builds the image defined in `Dockerfile`
2. Docker starts a container with your repo mounted at `/workspace`
3. Inside the container, the script runs `uv sync`
4. Inside the container, the script launches:
   ```bash
   claude --model opus --effort max --dangerously-skip-permissions
   ```
5. The agent reads the instructions in `CLAUDE.md`, the problem in `problem.md`, and the diary in `diary.md` — then gets to work autonomously without asking for permission on any actions.

If you want to stop the session, quit Claude as normal. The container will then exit. Your repo files remain on your machine because the repo folder is mounted into the container.

**Why this is safe:** the container can only see the repo folder you mounted into `/workspace`. It does not automatically have access to your home directory, SSH keys, or anything outside that folder. If the agent does something unexpected, the damage is limited to the clone.

---

## Quickstart

1. Clone a fresh copy of the repo you want to work on for the agent
2. Copy `CLAUDE.md`, `problem.md`, `diary.md`, and `pyproject.toml` into your repo
3. Add `Dockerfile`, `.dockerignore`, and `run_agent.sh`
4. Fill in `problem.md`
5. Optionally set a step budget by editing the `BUDGET:` line at the top of `diary.md`
6. Run `./run_agent.sh`
