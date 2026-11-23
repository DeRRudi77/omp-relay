---
name: relay-verify
description: "Drive a change in a real browser to confirm it works end-to-end via the relay-verifier agent: renders, behaves, no new console errors, isolation holds. Use for /relay-verify, browser-check this, or confirm the flow works. Needs the repo to say how to run the app (.omp/relay.md `## Verify`, or AGENTS.md / CLAUDE.md)."
argument-hint: "<optional: what changed / flow to verify; defaults to the diff vs the base branch>"
---

Dispatch the **relay-verifier** agent to browser-verify the target in the `User:` text.

## Steps

1. **Resolve the target.** Empty → the current change vs the default branch: `git diff $(git merge-base origin/<base> HEAD)` (committed and uncommitted edits) plus the untracked files `git ls-files --others --exclude-standard` lists; pass a short summary of what changed (files, behaviour) and the diff stat, not the full diff. A flow description or a bug report → that, as the flow to drive. A worktree path → run from there.
2. **Check it can run at all.** Resolve `PROFILE` as in `skill://relay-feature/SKILL.md` ("Project guidance"). If neither a `## Verify` section nor `AGENTS.md` / `CLAUDE.md` says how to run the app locally, say so and stop; do not guess a command. If the change has no runtime surface (docs, CI config, a library with no UI or HTTP), say that and stop.
3. **Dispatch** with `task` (`agent: relay-verifier`, `solutionSpace` like `flow known; defects open`), `context` = `PROFILE` verbatim, the change summary, and `WORKTREE_PATH` (this line verbatim: **"Work inside the worktree at `<WORKTREE_PATH>`. All file paths, `cwd` settings, and tool calls must target that directory, not the main checkout."**). Do not drive the browser yourself.
4. **Relay the verdict** (works / broken / could-not-verify), the steps driven, and any defects as `symptom → repro → expected`. Do not soften a `could-not-verify` into a pass.
5. **Offer follow-ups, do not perform them.** If broken, ask before handing the repro to the **relay-implementer**.

The verifier is read-only on code and leaves static-review nits to `/skill:relay-review`.

## Several branches at once

One verifier drives one app instance. Verify several worktrees in parallel only when the profile's `## Verify` says each worktree runs its own isolated stack (own host or port, own database); then dispatch one verifier per worktree in a single `tasks[]` batch, each with a distinct tab name in its prompt and its own `WORKTREE_PATH`. If the profile names a fan-out command, prefer it. Otherwise verify sequentially. Never point two verifiers at the same running instance.
