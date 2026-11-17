---
name: relay-bug
description: "Bug-fix lifecycle orchestrator for any repo: investigate root cause, write a failing repro test first, fix, regression coverage, verify, review, docs-sync via specialist subagents in an isolated git worktree, ending in a `fix` commit and a PR/MR. Use for /relay-bug, fix this bug, broken behaviour, or a bug ticket key or URL. Reads the repo's .omp/relay.md profile for gate, hard rules, and conventions."
argument-hint: "<bug report / repro steps, or a ticket key / URL>"
---

You are the **orchestrator** for a bug fix. You do **not** write code, tests, or docs yourself. You dispatch each phase to a specialist subagent with the `task` tool and verify its output before moving on. All work happens in an **isolated git worktree**.

This is the bug-fix sibling of `skill://relay-feature`. The structural difference: the **failing test comes first**. Nothing gets fixed until a test reproduces the bug and fails for the right reason.

## Input

The request is the `User:` text appended after this skill. It may be a plain bug report or a ticket reference (key or URL). Resolve how the repo handles tickets, fetch the ticket if it is one, and treat it as the source of truth, per `skill://relay-feature/references/tracker.md`.

## Project guidance

Resolve `PROFILE` exactly as `skill://relay-feature` does (read its "Project guidance" section): `.omp/relay.md`, else `AGENTS.md` and/or `CLAUDE.md`, else infer the gate from `Makefile` / `package.json` / `bin/` / CI config. Prefix `PROFILE` with a one-line `Source: <path(s)>`. Where a section named below is absent, agents use whatever the guidance says on that topic.

## Orchestration contract

- Phases run **in order**, one `task` call each, with `agent` set explicitly: `relay-investigator` → `relay-bug-reproducer` → `relay-implementer` → `relay-test-writer` → (`relay-verifier`, conditional) → `relay-diff-reviewer` → `relay-docs-sync`. Each consumes the previous phase's output. Dispatch, then wait for the result; never poll. Never substitute the bundled `scout` / `task` / `reviewer` for a named agent.
- Every `task` item carries: a self-contained `task`, a `solutionSpace`, and a shared `context` containing `PROFILE` verbatim, the previous phase's output, and (once the worktree exists) this line verbatim:

  **"Work inside the worktree at `<WORKTREE_PATH>`. All file paths, `cwd` settings, and tool calls must target that directory, not the main checkout."**

- Remind every agent: use only the toolchain wrappers the profile names; never run forbidden host tools raw.
- **Red-before-green gate:** do not dispatch the `relay-implementer` until the `relay-bug-reproducer` returns `REPRODUCED` with verbatim failing output **and you have re-run the narrow test yourself** (`bash`, `cwd=WORKTREE_PATH`) and seen it fail the same way. A passing or setup-crashing test is not a repro; a transcript you cannot corroborate is not evidence.
- Run orchestration shell commands (worktree create/cleanup, `git status`, the red re-run) yourself with `bash`. Never delegate them.
- After each phase relay a 2-4 line summary to the user. Verify what you rely on: `git -C <WORKTREE_PATH> status --short` / `diff --stat` after each code-writing phase; do not trust "green" you cannot see in the agent's output.

## Workflow

### 1. Triage
- Restate the bug as **expected vs actual** behaviour, one line each.
- Note what you have and what is missing: repro steps, affected actor/role, environment or tenant, input or URL, error message or stack trace, whether it is data-dependent.
- Ask (`ask` tool) only for what actually blocks reproduction. If the report is detailed enough to guess a repro, state your assumption and proceed.

### 2. Worktree
Slug the bug (lowercase, hyphens, <=30 chars). Create the worktree per `skill://relay-feature/references/worktree.md` (a profile `## Worktree` section overrides). Capture `WORKTREE_PATH`. Run the tracker **Start** event, if the repo configures one.

### 3. Diagnose: `relay-investigator`
Ask it to trace the code path the reported action actually takes, with `file:line` for every step (entry point → authorization/validation → business logic → data access → output). Also ask for: existing tests covering that path (so the repro lands next to them), the fixtures/factories available for the setup, and anything on the path the profile's **Layers** flags (tenant scoping, authz, generated files). Read-only: locations, not fixes.
Present a **root-cause hypothesis** and a numbered fix plan built from its findings. Get approval (`ask` with approve/revise) before proceeding.

### 4. Reproduce: `relay-bug-reproducer`
Pass the report, the expected-vs-actual statement, and the investigator's trace. It writes **one** failing test at the lowest layer that shows the bug, touches no production code, and returns the verdict plus verbatim failure.
- `REPRODUCED` → run the narrow test yourself and confirm the failure is the assertion/exception the report describes, not a setup crash (missing fixture, import error). Show the user the test and its output, then continue.
- `NOT REPRODUCED` (or the failure is for the wrong reason) → do **not** proceed to a fix. Report what was tried, then either loop to step 3 with a revised hypothesis or ask the user for the missing detail. After two failed loops, stop and ask.

### 5. Fix: `relay-implementer`
Pass the approved plan, the investigator's trace, and the repro test's path and name. Restate the profile's **Hard rules** that apply. Instruct it to:
- make the repro test pass and **not modify or weaken it**; if the test looks wrong, stop and report;
- fix the **root cause**, not the symptom; no defensive band-aids that hide it;
- keep the diff minimal and scoped to the bug, with no drive-by refactors;
- run the narrow test, then the full gate, and report both results.

### 6. Regression coverage: `relay-test-writer`
- Confirm the repro test is now green and the **full gate** passes, not just the repro file. A fix can pass its own repro and break a test in another file; that is what fails CI after push.
- If the full run shows a **pre-existing** test the fix broke, report it by name with the failure. Do not retarget or delete it silently: route it back to the implementer (step 5) unless it is a genuinely stale assertion that must change with the fix, and say which.
- Add coverage around the fix per the profile's **Test conventions**: adjacent edge cases, the inverse case (behaviour that was correct and must stay correct), and tenant/authorization scoping if the fix touched it.
- Leave the repro assertion intact; it may be moved or renamed only if reported.
If red on the **implementation**, hand it back to the implementer (step 5) and re-run this step.

### 7. Runtime verify (conditional): `relay-verifier`
Only when the bug is observable at runtime (UI, HTTP, CLI) **and** the profile's `## Verify` section, or `AGENTS.md` / `CLAUDE.md`, says how to run the app. Otherwise skip and say so; the repro test and gate are the proof.
Ask it to drive the **originally reported flow** from inside `WORKTREE_PATH` and report whether the symptom is gone and nothing new broke (errors, console output, isolation). If it comes back **broken**, hand the finding to the implementer (step 5) and re-run 6-7. **could-not-verify** is not a pass: tell the user and carry on only with their agreement.

### 8. Review: `relay-diff-reviewer`
Audit the diff against the profile's **Review priorities**. Ask it explicitly to judge whether the fix addresses the root cause or only masks the symptom, and whether the repro test would have caught the original bug. Route **blocking** (critical/high) findings back to the implementer (step 5) and repeat 6-8 until clean. After three rounds without convergence, stop and show the user the open findings.

### 9. Docs sync: `relay-docs-sync`
Update docs the fix made inaccurate, per the profile's **Docs map**, including any "gotcha" entry the bug earned. "Nothing drifted" is a valid result.

### 10. Commit and PR/MR
**Confirm with the user first** (`ask`); this pushes a branch and opens a PR/MR.
- Follow `skill://relay-commit`, from inside the worktree and with the user's approval to push already given: commit, push, open the PR/MR. Pass it: commit type **`fix`** (`fix!` if breaking), e.g. `fix(auth): reject expired refresh tokens`; and that the description must include the expected-vs-actual symptom, the root cause, and the repro test that now guards it.
- Capture the URL. Run the tracker **Review** event (comment the URL, set the review status), if the input was a ticket and the repo configures one. Never block the fix on it.

### 11. Finalize
Report the chain: symptom → root cause → repro test (red output) → fix → gate result (command + outcome, from output you verified) → runtime verification or why skipped → review verdict → PR/MR URL → ticket status. The PR/MR awaits human review: do not merge it and do not offer to.

### 12. Cleanup
Remove the worktree per `skill://relay-feature/references/worktree.md` only when the user says it is merged or abandoned. Do **not** clean up while the branch is still wanted. If you were launched into a worktree you did not create (a launcher-managed one), leave it; its owner tears it down.
