# Relay profile

<!--
Read by the relay-feature / relay-bug / relay-implement / relay-review / relay-grug skills and their agents
(relay-investigator, relay-bug-reproducer, relay-implementer, relay-test-writer, relay-diff-reviewer, relay-docs-sync, relay-grug).
Facts only; verified against the repo. Delete sections that do not apply.
Agents treat this file as outranking their generic defaults.
-->

## Project

<One paragraph: what this repo is, what it ships, who/what consumes it.>

## Gate

- **Full gate** (mirrors CI; green is the source of truth): `<command>`
- **Narrow test**: `<command to run one test file / filter>`
- **Toolchain rules**: <how tools are run (wrappers, containers); what must never be run raw on the host and why>
- **Needs runtime**: <Docker / network / creds, if the gate needs them>

## Layers

| Layer | Where | Notes |
|---|---|---|
| <layer> | `<path>` | <what it is, how it couples to other layers> |

### Things worth flagging near a change

- <repo-specific smell the investigator should always call out>

## Hard rules

Non-negotiable for the implementer.

- <rule, with the reason or ADR link>

## Test conventions

- <runner, file layout, naming, helper libs, fixtures dir>
- <what must be covered for this repo: failure paths, consumer-visible contract, drift gates>
- <environment limits: no network at test time, pinned versions, lint gates on tests>

## Review priorities

| Finding | Severity |
|---|---|
| <e.g. behaviour change with no test> | critical |
| <e.g. new config key undocumented> | high |

## Complexity hot spots

Where demons hide in this repo (read by `relay-grug`).

- <e.g. a config knob that could be a default>

## Docs map

| Changed | Update |
|---|---|
| <thing> | `<doc>` |

## Verify

Only if the changed surface can be exercised at runtime (read by the `relay-verifier` agent via `relay-verify`, `relay-feature` and `relay-bug`).

- **Run command**: <e.g. `bin/dev`; from inside the worktree>
- **Where to reach it**: <URL / domain pattern, esp. if derived from the worktree directory name>
- **Roles / accounts / seed data** needed to hit typical flows: <...>
- **Isolation checks**: <the boundaries to probe with a second principal: tenant, role, ownership; which URLs/ids to tamper with and what refusal looks like (e.g. 403 vs 404)>
- **Recovery**: <the one allowed recovery step per failure (e.g. pending migrations → `<migrate command>`), else a single restart>

## Delivery

- **Commit style**: <Conventional Commits? what the type drives (release bump)?>
- **Base branch**: <main>
- **PR/MR recipe**: <exact command; omit to use `gh pr create` / `glab mr create` with an API fallback>
- **Attribution**: <omit for an `Assisted-by: omp:<model>` commit trailer and PR/MR footer; `pr-only` for the footer alone; `none` for neither; or the exact trailer the repo requires>
- **Prose pass**: <omit for none; or a skill name (e.g. `humanizer`) to run commit/PR text through>

## Tracker

Only if tickets drive this repo's work. Read by the `relay-feature` and `relay-bug` skills per `skill://relay-feature/references/tracker.md`; leave out any event you do not want synced.

- **Detect**: <ticket key pattern and/or URL pattern>
- **Fetch**: <tool(s) that read a ticket and its comments, e.g. an MCP server's get-issue / list-comments>
- **Start**: <status to set when work begins, or omit>
- **Review**: <comment the PR/MR URL and set status "<name>", or omit>

## Worktree

Only if the defaults in `skill://relay-feature/references/worktree.md` do not fit.

- **Branch / directory**: <e.g. `worktrees/<slug>` both>
- **Create command**: <e.g. `wtp add -b worktrees/<slug> --quiet`>
- **Post-create**: <files to copy that are gitignored>
- **Extra isolation / cleanup**: <e.g. COMPOSE_PROJECT_NAME=<slug>, `docker compose down -v`>

## Conditional skills

- <e.g. when adding `.tf` files, load the `terraform-skill` skill before finalizing>
