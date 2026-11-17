---
name: review
description: "Review a diff, branch, worktree, or file via the diff-reviewer agent in any repo: blast radius, untested behaviour, config/schema/doc drift, correctness, security. Read-only and severity-ranked. Use for /review, review this diff, or review this MR/PR."
argument-hint: "<nothing (current diff vs default branch), or a branch / worktree path / file>"
---

Dispatch the **diff-reviewer** agent on the target in the `User:` text.

## Steps

1. **Resolve the target.** Empty → current diff vs the default branch (`git diff <base>...HEAD` plus `git status`). A branch, worktree path, or file → that. For a worktree, pass its absolute path and say every `cwd` must be there.
2. **Guidance.** Resolve `PROFILE` as in `skill://feature/SKILL.md` ("Project guidance"): `.omp/pipeline.md` if present, else `AGENTS.md` and/or `CLAUDE.md`. Pass it verbatim in `context` so the reviewer applies this repo's rules. None: the reviewer uses its generic priorities.
3. **Dispatch** with `task` (`agent: diff-reviewer`, with a `solutionSpace` like `review defects open; no known bug`). Do not review inline.
4. **Relay the findings verbatim**, most severe first, with the agent's one-line verdict.
5. **Offer follow-ups, do not perform them.** Ask before routing blocking findings to the **implementer**, missing coverage to the **test-writer**, or doc drift to **docs-sync**.

The reviewer never edits code. Fixes are a separate, explicit step.
