---
name: relay-init
description: "Bootstrap or refresh a repo's .omp/relay.md profile (gate command, toolchain rules, layers, hard rules, test conventions, review priorities, docs map, delivery conventions) so the feature / bug / implement / review / grug skills and their agents work well in that repo. Use for /relay-init, set up the feature pipeline here, or when the profile is missing or stale."
argument-hint: "<nothing (current repo), or hints about the repo's conventions>"
---

Create or refresh `<repo root>/.omp/relay.md`, the **optional** structured profile the generic relay agents read. Without it they fall back to the repo's `AGENTS.md` / `CLAUDE.md`; the profile adds explicit review severities, a docs map, hard rules, and delivery recipes. Skip it for small repos whose `AGENTS.md` already covers the gate and conventions. You do the synthesis; the **relay-investigator** agent does the read-only survey.

## Steps

1. **Existing profile?** If `.omp/relay.md` exists, read it. The job becomes a refresh: verify every claim, fix the stale ones, keep the user's wording elsewhere.
2. **Survey** with `task` (`agent: relay-investigator`, `solutionSpace: repo conventions open; survey only`). Ask it to report, with `file:line` evidence:
   - the CI definition and the single local command that mirrors it (`Makefile`, `package.json` scripts, `bin/`, `.gitlab-ci.yml`, `.github/workflows/`, pre-commit config); how a single test is run; whether tools run through wrappers or containers and what must never run raw on the host;
   - the layers of the codebase and how they couple; generated or committed outputs that must be regenerated; config keys and where they are documented; pinned versions;
   - test layout, helpers, fixtures, and environment limits;
   - what depends on this repo (consumers, public API/schema/CLI/file formats), ADRs, and decisions that constrain changes;
   - docs that name code things (README, CONTRIBUTING, config references, agent files);
   - commit style (inspect `git log`), release tooling that reads commit messages, PR/MR host (`git remote get-url origin`), ticket key pattern, existing worktree tooling (`.wtp.yml`).
3. **Draft** from `skill://relay-init/templates/relay.md`. Fill only what the survey evidences. Drop sections that do not apply. Never invent a command; if the gate or a rule is unclear, ask.
4. **Confirm** (`ask`) the items that are judgment, not fact: the exact gate command, hard rules, and the severity ranking in Review priorities. Pre-fill your best guess. For `## Tracker`, the survey only finds the key pattern: ask whether tickets drive work here, which tracker, and the status names for start and review; take the fetch tools from the tracker MCP tools mounted in your own session. Omit the section if tickets do not drive work.
5. **Write** `.omp/relay.md`. Keep it dense and factual; a profile over ~200 lines is doing too much.
6. Report what you wrote and what you left out. Do **not** commit; the user decides whether the profile is tracked.

Do not duplicate `AGENTS.md` / `CLAUDE.md` wholesale: link or summarize, and put only relay-specific facts here. Existing harness files (`CLAUDE.md`, `AGENTS.md`, `.claude/agents/*.md`, `.claude/rules/*.md`) are a good source of hard rules and layers: lift their facts, drop their harness-specific wording.
