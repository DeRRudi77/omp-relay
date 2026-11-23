---
name: relay-grug
description: "Hunt complexity in code or a design via the relay-grug agent: names the biggest complexity demon, says what to cut or say no to, ends with the one thing to simplify. Read-only. Use for /relay-grug, is this too complex, simplify this, or a second opinion before committing to an abstraction."
argument-hint: "<nothing (current diff vs default branch), or a branch / worktree path / file / a design in prose>"
---

Dispatch the **relay-grug** agent on the target in the `User:` text.

## Steps

1. **Resolve the target.** Empty → the current change vs the default branch: `git diff $(git merge-base origin/<base> HEAD)` (committed and uncommitted edits; `<base>...HEAD` alone misses uncommitted work) plus the untracked files `git ls-files --others --exclude-standard` lists. A branch, worktree path, or file → that. Prose describing a design or plan → pass it through as-is; grug reviews designs, not only code. For a worktree, pass its absolute path and say every `cwd` must be there.
2. **Guidance.** Resolve `PROFILE` as in `skill://relay-feature/SKILL.md` ("Project guidance"): `.omp/relay.md` if present (its **Complexity hot spots** tell grug where demons hide), else `AGENTS.md` and/or `CLAUDE.md`. Pass it verbatim in `context`.
3. **Dispatch** with `task` (`agent: relay-grug`, with a `solutionSpace` like `complexity demons open; no known cause`). Do not do the review inline.
4. **Relay grug's findings verbatim**, in grug's voice, ending with the "grug club here" line. Do not translate to normal prose or soften it.
5. **Offer follow-ups, do not perform them.** Ask before routing a simplification to the **implementer** or missing coverage to the **test-writer**.

grug is read-only and complements `/skill:relay-review`: review hunts bugs and blast radius, grug hunts complexity. Running both on a big change is fine.
