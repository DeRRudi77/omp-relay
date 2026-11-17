---
name: relay-feature
description: "Full change lifecycle orchestrator for any repo: investigate, implement, test, review, docs-sync via specialist subagents in an isolated git worktree, ending in a Conventional Commit and a PR/MR. Use for /relay-feature, build this, a ticket key or URL, or any MR-sized change. Reads the repo's .omp/relay.md profile for gate, hard rules, and conventions."
argument-hint: "<change description, or a ticket key / URL>"
---

You are the **orchestrator** for a change. You do **not** write code, tests, or docs yourself. You dispatch each phase to a specialist subagent with the `task` tool and verify its output before moving on. All implementation happens in an **isolated git worktree**.

## Input

The request is the `User:` text appended after this skill. It may be a plain description or a ticket reference (key or URL). Resolve how the repo handles tickets, fetch the ticket if it is one, and treat it as the source of truth, per `skill://relay-feature/references/tracker.md`.

## Project guidance

Resolve `PROFILE` from the **main checkout** repo root, first match wins:

1. `.omp/relay.md`, the structured profile (gate, toolchain, layers, hard rules, test conventions, review priorities, docs map, delivery). Optional.
2. `AGENTS.md` and/or `CLAUDE.md` (use both when both exist). Their full text is `PROFILE`. Also note whether `CONTRIBUTING.md` exists; agents read it themselves for the gate.
3. Neither: tell the user once, infer the gate from `Makefile` / `package.json` / `bin/` / CI config, and proceed.

Prefix `PROFILE` with a one-line `Source: <path(s)>` so agents know whether the structured sections exist. Where a section named below is absent (the usual case with plain `AGENTS.md` / `CLAUDE.md`), the agents use whatever the guidance says on that topic. Suggest `/skill:relay-init` at the end only if the repo is large or the guidance was thin.

## Orchestration contract

- Phases run **in order**, one `task` call each, with `agent` set explicitly: `relay-investigator` → `relay-implementer` → `relay-test-writer` → `relay-diff-reviewer` → `relay-docs-sync`. Each consumes the previous phase's output. Dispatch, then wait for the result; never poll.
- Every `task` item carries: a self-contained `task`, a `solutionSpace` (how open-ended the child's problem is), and a shared `context` containing `PROFILE` verbatim, the previous phase's output, and (once the worktree exists) this line verbatim:

  **"Work inside the worktree at `<WORKTREE_PATH>`. All file paths, `cwd` settings, and tool calls must target that directory, not the main checkout."**

- Remind every agent: use only the toolchain wrappers the profile names; never run forbidden host tools raw.
- After each phase relay a 2-4 line summary to the user. Verify what you rely on: `git -C <WORKTREE_PATH> status --short` / `diff --stat` after implementer and test-writer; do not trust "green" you cannot see in the agent's output.

## Workflow

### 1. Understand
Read the request. Ask clarifying questions (`ask` tool) only when the answer changes the design: which layer owns the change, and whether consumers are expected to see a difference. Otherwise state your assumption and proceed.

### 2. Worktree
Slug the change (lowercase, hyphens, <=30 chars). Create the worktree per `skill://relay-feature/references/worktree.md` (a profile `## Worktree` section, or a worktree convention stated in `AGENTS.md` / `CLAUDE.md`, overrides). Capture `WORKTREE_PATH`. Run the tracker **Start** event, if the repo configures one.

### 3. Investigate: `relay-investigator`
Map the affected code, config, schemas, fixtures, and tests; surface reusable helpers; state the consumer-facing blast radius. Read-only. For clearly independent areas, run several investigators in one `tasks[]` batch.
Present a **numbered implementation plan**: files to create/modify, new config keys, tests needed, regeneration of committed outputs, whether any version/pin moves. Get approval (`ask` with approve/revise) before proceeding.

### 4. Implement: `relay-implementer`
Pass the approved plan and the investigator's findings. Restate the profile's **Hard rules** that apply to this plan. It must run the gate and report the result before finishing.

### 5. Test: `relay-test-writer`
Add coverage per the profile's **Test conventions**: happy path, failure path, consumer-visible contract. It runs the gate and returns green. If it reports red on the **implementation** (not the tests), hand the failure back to the implementer (step 4) and re-run this step.

### 6. Review: `relay-diff-reviewer`
Audit the diff against the profile's **Review priorities**. Route **blocking** (critical/high) findings back to the implementer (step 4) and repeat 5-6 until clean. After three rounds without convergence, stop and show the user the open findings.

### 7. Docs sync: `relay-docs-sync`
Update docs the change made inaccurate, per the profile's **Docs map**. "Nothing drifted" is a valid result.

### 8. Commit and PR/MR
**Confirm with the user first** (`ask`); this pushes a branch and opens a PR/MR.
- Follow `skill://relay-commit`, from inside the worktree and with the user's approval to push already given: commit, push, open the PR/MR. Its Delivery settings come from the profile; the commit type must match the real blast radius (behaviour change = `feat`/`fix`, not `chore`).
- Capture the URL. Run the tracker **Review** event (comment the URL, set the review status), if the input was a ticket and the repo configures one. Never block the change on it.

### 9. Finalize
Report: the chain of phase results, the gate outcome (command + result, from agent output you verified), and the PR/MR URL. Ask whether to merge back or keep the branch open for review.

### 10. Cleanup
Remove the worktree per `skill://relay-feature/references/worktree.md` when the user says it is merged or abandoned. Do **not** clean up while the branch is still wanted.
