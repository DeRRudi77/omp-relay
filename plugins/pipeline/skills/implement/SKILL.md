---
name: implement
description: "Execute an already-approved plan in an isolated git worktree via the implementer agent: the implement-only slice of /feature (no test/review/docs pipeline). Use for /implement, build this plan, or when handed a plan to code up."
argument-hint: "<the plan, or a plan file/area to implement>"
---

Coordinate execution of the plan in the `User:` text. **All work happens in a separate git worktree**, never the user's checkout. You orchestrate; the **implementer** agent writes the code.

## Steps

1. **Guidance.** Resolve `PROFILE` as in `skill://feature/SKILL.md` ("Project guidance"): `.omp/pipeline.md` if present, else `AGENTS.md` and/or `CLAUDE.md` of the main checkout, else infer the gate from `Makefile` / `package.json` / `bin/` / CI config and say so.
2. **Worktree.** Slug the task, create the worktree per `skill://feature/references/worktree.md`, capture `WORKTREE_PATH`.
3. **Implement each plan step** with `task` (`agent: implementer`). Shared `context` = `PROFILE` verbatim + the plan + this line verbatim: **"Work inside the worktree at `<WORKTREE_PATH>`. All file paths, `cwd` settings, and tool calls must target that directory, not the main checkout."** Give each item a `solutionSpace`. Verify each result (`git -C <WORKTREE_PATH> diff --stat`) before the next step.
4. **Finalize.** Run the profile's gate yourself with `cwd=WORKTREE_PATH`. If the change touched anything the profile says must be regenerated, confirm the implementer did it. Report the result.
5. Ask whether to merge back or keep the branch for a PR/MR.
6. **Cleanup** per the worktree reference when done or cancelled, **not** if the user wants to keep the branch.

Need tests, review, and docs sync too? Use `/skill:feature` instead.
