# omp-relay

Repo-agnostic change pipelines for omp. An orchestrator skill dispatches specialist subagents in an isolated git worktree and ends in a PR/MR.

| Skill | What it does |
|---|---|
| `/relay-feature` | investigate → implement → complexity check → test → browser verify (when runnable) → review → docs-sync → commit and PR/MR |
| `/relay-bug` | like `/relay-feature`, but a failing repro test must exist (red) before any fix is written |
| `/relay-implement` | implement an approved plan in a worktree, no test/review/docs pipeline |
| `/relay-review` | read-only review of a diff, branch, worktree, file, or PR/MR; findings are Conventional Comments, placed inline on a PR/MR |
| `/relay-grug` | complexity review |
| `/relay-verify` | drive a change in a real browser (omp's own isolated one) to confirm it renders, behaves, has no new console errors, and respects isolation boundaries |
| `/relay-init` | create or refresh a repo's `.omp/relay.md` profile |
| `/relay-commit` | commit (short Conventional Commits), push, open a PR (GitHub) or MR (GitLab, others) with a CLI-to-API fallback; then watches the pipeline and fixes failures itself; also what `/relay-feature` and `/relay-bug` end with |

Agents: `relay-investigator`, `relay-bug-reproducer`, `relay-implementer`, `relay-test-writer`, `relay-verifier`, `relay-diff-reviewer`, `relay-docs-sync`, `relay-grug`.

Every skill and agent is prefixed `relay-`. omp does not namespace agents, and it gives a clashing skill name to whichever source ranks higher, which would break the skills' links to each other (`skill://relay-feature/references/...`). Invoke a skill as `/skill:relay-bug`.

## Install

```
omp plugin marketplace add derrudi77/omp-relay
omp plugin install relay@omp-relay
```

Run `/reload-plugins` in a running session.

## Requirements

- **Models (optional).** Every agent resolves its model from its own role, `relay_<agent>` (dashes become underscores), then from the shared `relay_default` role. If neither is set, the agent uses omp's normal task-agent model. Configure nothing, one default, or any subset of agents:

  ```yaml
  modelRoles:
    relay_default: <provider/model[:thinking]>       # used by every relay agent not listed below
    relay_investigator: <provider/model[:thinking]>
    relay_grug: <provider/model[:thinking]>
    relay_implementer: <provider/model[:thinking]>
    relay_test_writer: <provider/model[:thinking]>
    relay_verifier: <provider/model[:thinking]>
    relay_diff_reviewer: <provider/model[:thinking]>
    relay_bug_reproducer: <provider/model[:thinking]>
    relay_docs_sync: <provider/model[:thinking]>
  ```

  Resolution order per agent: `task.agentModelOverrides.<agent-name>` → `relay_<agent>` → `relay_default` → omp's task-agent fallback. Leave a role out to inherit the default.

  Upgrading from 0.6: the tier roles `relay_light`, `relay_fast`, `relay_build` and `relay_deep` are no longer read. Rename them to per-agent roles or collapse them into `relay_default`.

- `git`. `wtp` is used for worktrees when the repo has a `.wtp.yml`; otherwise plain `git worktree`.
- `gh` or `glab` for opening the PR/MR, unless the repo's profile gives its own recipe. If the CLI is missing or fails, `/relay-commit` falls back to the forge's API through the same tool.

## Configuration: `.omp/relay.md`

The plugin has no settings of its own. omp's plugin settings (`omp plugin config`) are for extension modules; skills are plain markdown and cannot read them, and the things that vary here (gate command, PR recipe, tracker) differ per repo anyway. Everything lives in `<repo>/.omp/relay.md`, which the skills and agents read first. Without it they fall back to the repo's `AGENTS.md` / `CLAUDE.md`. Run `/relay-init` to draft one from the repo, or start from [the template](plugins/relay/skills/relay-init/templates/relay.md).

Sections: Gate, Layers, Hard rules, Test conventions, Review priorities, Complexity hot spots, Docs map, Verify, Delivery, Tracker, Worktree, Conditional skills. All optional.

Ticket trackers are not built in. A `## Tracker` section tells the skills how to detect, fetch and update tickets with whatever MCP tools you have mounted; see [tracker.md](plugins/relay/skills/relay-feature/references/tracker.md).

Delivery settings (`## Delivery`): commit style, base branch, an exact PR/MR recipe, attribution trailer, an optional prose-pass skill, and CI watch (on by default). `/relay-commit` reads them; see its `Settings` table for defaults.

## Updating

```
omp plugin marketplace update omp-relay
omp plugin upgrade relay@omp-relay
```

Upgrades are detected by the `version` in `.omp-plugin/marketplace.json`; bump it with every change.

## License

MIT
