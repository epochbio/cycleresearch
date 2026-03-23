# CLAUDE.md

## Non-negotiables
1. Every research step gets its own folder under `steps/`.
2. Update `diary.md` immediately after every step. No exceptions.
3. Use `uv run` for all Python execution. Never activate an environment manually.
4. Before starting each new step, re-read these non-negotiables.

---

## Setup

Dependencies are in `pyproject.toml`. To install: `uv sync`
To run a script: `uv run steps/step_NNN_.../run.py`
To add a package: add it to `pyproject.toml` under `[project] dependencies`, then `uv sync`

---

## Step Budget

Default: **30 steps**. Stop early if you reach a satisfactory conclusion — write a final
summary in `diary.md` explaining what was solved and why you're confident. If you hit 30
without a conclusion, stop and summarise what you'd try next. Do not exceed the budget.

---

## Two Step Types

### Experiment — `steps/step_NNN_experiment_<name>/`
- Write `run.py`, execute it with `uv run`
- Save stdout/stderr to `results.txt` in the same folder
- Update `diary.md`

### Reasoning — `steps/step_NNN_reasoning_<name>/`
- Write `reasoning.md` with: **Question**, **Argument**, **Conclusion**, **What would falsify this**
- Update `diary.md`

---

## Diary Format

Append to `diary.md` after every step:

```
## Step NNN — [Experiment|Reasoning] — <name>
**Steps remaining:** X
**Did:** <one sentence>
**Found:** <key result>
**Implies:** <so what>
**Next:** <what and why>
---
```

Also maintain a `## Hypotheses` section at the top of `diary.md`.
Mark each as ACTIVE, CONFIRMED, or KILLED. Kill explicitly — do not silently abandon.

---

## Strategy

- Prefer understanding over search. Brute force and SA are last resorts.
- If the same approach fails twice, kill it in the hypotheses list and move on.
- When stuck: write a reasoning step asking "what structure haven't I used yet?"
- Start with the smallest useful case before generalising.

---

## Starting a New Session

1. Read `problem.md`
2. Read `diary.md` (resume if prior work exists; check for `BUDGET:` override)
3. Run `uv sync` to ensure environment is ready
4. Begin with a reasoning step: restate the problem, identify key structure, state first hypothesis
