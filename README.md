# omp-pipeline

Repo-agnostic change pipelines for omp. An orchestrator skill dispatches specialist subagents in an isolated git worktree and ends in a PR/MR.

| Skill | What it does |
|---|---|
| `/feature` | investigate → implement → test → review → docs-sync → commit and PR/MR |
| `/bug` | like `/feature`, but a failing repro test must exist (red) before any fix is written |
| `/implement` | implement an approved plan in a worktree, no test/review/docs pipeline |
| `/review` | read-only review of a diff, branch, worktree, file, or PR/MR; findings are Conventional Comments, placed inline on a PR/MR |
| `/grug` | complexity review |
| `/pipeline-init` | create or refresh a repo's `.omp/pipeline.md` profile |
| `/commit-and-request` | commit (short Conventional Commits), push, open a PR (GitHub) or MR (GitLab, others) with a CLI-to-API fallback; also what `/feature` and `/bug` end with |

Agents: `investigator`, `bug-reproducer`, `implementer`, `test-writer`, `diff-reviewer`, `docs-sync`, `grug`.

## Install

```
omp plugin marketplace add derrudi77/omp-pipeline
omp plugin install pipeline@omp-pipeline
```

Run `/reload-plugins` in a running session.

## Requirements

- **Model roles.** The agents use `model: "@pipeline_deep"` (implementer, test-writer, bug-reproducer, diff-reviewer) and `"@pipeline_fast"` (investigator, docs-sync, grug). Define both in `config.yml`:

  ```yaml
  modelRoles:
    pipeline_deep: <provider/model[:thinking]>
    pipeline_fast: <provider/model[:thinking]>
  ```

- `git`. `wtp` is used for worktrees when the repo has a `.wtp.yml`; otherwise plain `git worktree`.
- `gh` or `glab` for opening the PR/MR, unless the repo's profile gives its own recipe. If the CLI is missing or fails, `/commit-and-request` falls back to the forge's API through the same tool.

## Configuration: `.omp/pipeline.md`

The plugin has no settings of its own. omp's plugin settings (`omp plugin config`) are for extension modules; skills are plain markdown and cannot read them, and the things that vary here (gate command, PR recipe, tracker) differ per repo anyway. Everything lives in `<repo>/.omp/pipeline.md`, which the skills and agents read first. Without it they fall back to the repo's `AGENTS.md` / `CLAUDE.md`. Run `/pipeline-init` to draft one from the repo, or start from [the template](plugins/pipeline/skills/pipeline-init/templates/pipeline.md).

Sections: Gate, Layers, Hard rules, Test conventions, Review priorities, Complexity hot spots, Docs map, Verify, Delivery, Tracker, Worktree, Conditional skills. All optional.

Ticket trackers are not built in. A `## Tracker` section tells the skills how to detect, fetch and update tickets with whatever MCP tools you have mounted; see [tracker.md](plugins/pipeline/skills/feature/references/tracker.md).

Delivery settings (`## Delivery`): commit style, base branch, an exact PR/MR recipe, attribution trailer, and an optional prose-pass skill. `/commit-and-request` reads them; see its `Settings` table for defaults.

## Updating

```
omp plugin marketplace update omp-pipeline
omp plugin upgrade pipeline@omp-pipeline
```

Upgrades are detected by the `version` in `.omp-plugin/marketplace.json`; bump it with every change.

## License

MIT
