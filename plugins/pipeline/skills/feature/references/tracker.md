# Tracker sync

Shared by `feature` and `bug`. The skills name no tracker and no tool. The repo says which tracker it uses and how, in the profile's `## Tracker` section (or a tracker convention stated in `AGENTS.md` / `CLAUDE.md`). Tracker sync is **orchestration**: you do it inline, never in a delegated phase.

## Events

| Event | When | What the `## Tracker` section supplies |
|---|---|---|
| **Detect** | Reading the request | How a ticket reference looks (key pattern, URL pattern) |
| **Fetch** | Input is a ticket | Which tools read the ticket and its comments |
| **Start** | Worktree created | The status to set, if any |
| **Review** | PR/MR opened | The status to set, and the comment to post (the PR/MR URL) |

An event the section does not mention is skipped. Fetch and Start are optional; most repos only need Detect, Fetch and Review.

## Rules

- **Use only the tools the section names.** MCP tool names differ per machine. Read the tool's `xd://` doc before first use. If a named tool is not mounted, warn once and continue without tracker sync.
- **Source of truth.** A fetched ticket (description and comments) outranks the user's paraphrase of it.
- **Never block the work.** A tracker failure (unreachable, unknown status name, permission denied) is a one-line warning to the user, then continue.
- **No section configured.** If the request looks like a ticket reference (a `KEY-123` pattern or an issue-tracker URL) and the repo configures no tracker, do not guess a tool: ask the user (`ask`) to paste the ticket text, treat that as the request, and skip all tracker events. Suggest adding a `## Tracker` section at the end.
- **Plain-text request.** No ticket, no tracker events.
- Report the ticket's final status in the finalize step, or say it was not synced and why.
