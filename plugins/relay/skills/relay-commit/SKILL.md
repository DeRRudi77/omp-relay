---
name: relay-commit
description: "Commit the current work as short Conventional Commits, push a topic branch, and open a pull request (GitHub) or merge request (GitLab, Gitea, Bitbucket, ...) on whatever forge the repo uses. Replaces forge-specific commit-and-pr / commit-and-mr skills. Use for /relay-commit, commit and PR, commit and MR, open a PR/MR, or ship this. Reads the repo's Delivery settings from .omp/relay.md or AGENTS.md / CLAUDE.md. Keeps commit messages and descriptions short."
argument-hint: "<optional: notes for the description, or a ticket key>"
---

Two phases: **commit**, then **publish**. Both are governed by one rule, and both take their settings from the repo.

## Settings

Resolve once, first match wins per setting:

1. The profile's **Delivery** section in `.omp/relay.md` (read it from the main checkout's repo root).
2. What the repo's `AGENTS.md` / `CLAUDE.md` / `CONTRIBUTING.md` says about commits, branches, PRs/MRs.
3. Your user-level instructions already in context (they apply to every repo).
4. The defaults in this skill.

Settings this skill reads:

| Setting | Default |
|---|---|
| **Commit style** | Conventional Commits, as below |
| **Base branch** | the remote default: `git symbolic-ref --short refs/remotes/origin/HEAD` |
| **PR/MR recipe** | an exact command; replaces step 4 of Publish entirely |
| **Attribution** | an `Assisted-by` commit trailer plus a PR/MR footer; `pr-only`, `none` or a repo-specified trailer change that, as in [Attribution](#attribution) |
| **Prose pass** | none; if the setting names a skill (e.g. `humanizer`), run commit subjects/bodies and the PR/MR title/description through it after shortening, preserving syntax, issue references, commands, code blocks and facts |
| **CI watch** | `on`: after opening the PR/MR, watch its pipeline and fix failures (Phase 3). `off` skips it |

When another skill (`relay-feature`, `relay-bug`) calls this one, it may also pass the commit type to use, content the description must include, and that the user already approved pushing.

## The rule: short by default

Length is not a proxy for care. A reviewer reads the diff; prose exists only to supply what the diff cannot show: the *why*, and anything surprising. Write the short version first. Expand only when you can name the specific question a reader would otherwise have to ask.

**Cut on sight:** restating the diff in prose; a bullet per file or config key; anything visible from the file tree or the commit title; "Supporting changes:" / "Also:" / "Note that:" paragraphs; announcing structure ("Three things changed:") then explaining all three; test counts, tool versions, defensive justification.

**Keep:** the why, a non-obvious decision and its rejected alternative, a real risk to anyone downstream, the ticket reference.

## Phase 1: Commit

Budget: subject <=50 chars. Body <=4 lines, often zero. Never repeat the subject in the body, never put the diff in the message.

Follow [Conventional Commits](https://www.conventionalcommits.org): `type(scope): summary`.

- Types: `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `chore`, `build`, `ci`, `style`, `revert`. The type must match the real blast radius: a behaviour change is `feat`/`fix`, never `chore`. If release tooling reads commit messages (see the profile), the type picks the version bump.
- Summary imperative, lower-case, no trailing period. Breaking: `type!:` or a `BREAKING CHANGE:` footer.
- Body explains the *why*, never the *how*.

```
fix(events): take the last generated class as the payload

Codegen emits nested helpers above the class that references them, so
the first class is a helper for any nested schema.
```

That body earns its lines: the reason is invisible in the diff.

Steps:

1. `git status`, `git diff`, `git diff --cached`: see what actually changed. Work from the directory the change lives in (a worktree path, if given).
2. Split into logical commits when the diff spans unrelated concerns. Never `git add -A` blindly.
3. **Never** stage secrets or local env files (`.env`, credentials, tokens, key material). Flag any that are untracked and unignored.
4. If on the base branch, branch first: `type/short-description`, or the tracker's suggested branch name for a linked ticket. If already on a topic branch (e.g. a pipeline worktree branch), stay on it.
5. Commit, adding the attribution trailer, if any, with `git commit --trailer "Assisted-by: ..."`. Hooks (formatters, linters) may rewrite and restage files: re-check `git status` afterwards.
6. Report the SHA(s).

### Attribution

Attribution follows the [kernel-style](https://www.kernel.org/doc/html/latest/process/coding-assistants.html) `Assisted-by: omp:<model>` form. The setting picks where it goes:

| Setting | Commit trailer | PR/MR footer |
|---|---|---|
| omitted (default) | `Assisted-by: omp:<model>`, one line per model | yes |
| `pr-only` | none | yes |
| `none` | none | none |
| a trailer the repo specifies | that trailer, verbatim | only if it is an `Assisted-by` trailer, with its value |

List each distinct model that wrote part of the change; a commit's trailers cover that commit, the footer covers the whole branch:

- Files edited by a relay agent (`relay-implementer`, `relay-test-writer`, `relay-bug-reproducer`, `relay-docs-sync`): that agent's model. Read `omp config get modelRoles --json` and take `relay_<agent>` (hyphens to underscores), else `relay_default`.
- Files you edited yourself: the model you are running as.
- `<model>` is the bare model id: drop the provider (`amazon-bedrock/`), any region/vendor prefix (`us.anthropic.`) and the thinking suffix (`:high`). `amazon-bedrock/us.anthropic.claude-opus-5-5:high` → `claude-opus-5-5`.
- Model not resolvable: `omp` alone. Never guess a model name.

The footer is the description's own last paragraph, one line:

```
Assisted-by: omp:claude-opus-5-5, omp:gpt-6-luna
```

It does not count toward the description budget, and the prose pass leaves it untouched. No `Co-Authored-By` and no "Generated with" line anywhere.

## Phase 2: Publish

Budget: ~200 words of prose. One short paragraph of why, then tight bullets. The description is not where you prove the work was thorough.

1. Confirm the branch is not the base branch. If it is, stop.
2. `git push -u origin <branch>`. If the user asked only to "commit" (and no calling skill passed approval), stop after Phase 1 and ask first.
3. If the repo has a PR/MR template (`.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE/`, `.gitlab/merge_request_templates/`), follow its sections exactly but fill them tersely; `N/A` is a complete answer.
4. Open the request:
   - **A configured PR/MR recipe replaces everything below.** Run it.
   - Otherwise pick the forge from `git remote get-url origin`: GitHub → `gh pr create`; GitLab → `glab mr create`; Gitea/Forgejo → a mounted Gitea MCP's create-pull-request, if any; anything else → the API tool the user has, or the "create pull request" URL that `git push` prints.
   - **If the CLI fails** (not installed, not authenticated, or `glab` rejecting the remote because `~/.ssh/config` rewrites the host), use the forge's API instead of fighting it: `gh api -X POST repos/<owner>/<repo>/pulls -f head=<branch> -f base=<base> -f title=... -f body=...`, or `glab api -X POST "projects/<url-encoded-path>/merge_requests" -f source_branch=<branch> -f target_branch=<base> -f title=... -f description=...` (`%2F` for each `/` in the path). Pass multi-line bodies through a heredoc into a variable. Tell the user which path you took.
5. Title: the lead commit's subject, or one line spanning the commits. Description: the why, then a short bullet list. Include whatever the calling skill required.
6. Link the ticket if there is one: a key in the branch name or commits, or one the caller passed. Fetch its title or URL only if you need it, using the tools the repo's `## Tracker` section names (`skill://relay-feature/references/tracker.md`). No ticket, no line; never invent a reference.
7. End the description with the attribution footer, when the setting calls for one ([Attribution](#attribution)).
8. Report the PR/MR URL, then go to Phase 3. Mention the pipeline only if it is the first run of a new job or expected to fail.

## Phase 3: Watch the pipeline

Publishing is not done until the pipeline for the new PR/MR is green. Watch it and fix failures yourself; do not hand a red pipeline back to the user. Skip only when the **CI watch** setting is `off`, the repo has no CI for this branch (no checks appear after ~2 minutes), or a calling skill said it owns the pipeline.

**Watch.** Block on the pipeline, preferring the forge's own wait over a hand-rolled poll:

- GitHub: `gh pr checks <pr> --watch --fail-fast`
- GitLab: `glab ci status --live` on the branch, or poll `glab api projects/<id>/merge_requests/<iid>/pipelines` until the head pipeline reaches a terminal state
- Anything else: poll the forge's API/MCP every 30-60s

Run long waits as a background job or with a generous timeout; do not stop on the first timeout while the pipeline is still running.

**On failure:**

1. Pull the failing job logs (`gh run view --log-failed`, `glab ci trace <job>` or the jobs API). Read the actual error; never guess from the job name.
2. Classify:
   - **Infrastructure flake** (runner lost, network/registry timeout, cancelled by system, no code frame in the trace): retry the failed job/pipeline once. A second identical failure is a real failure.
   - **Caused by this change**: fix the root cause in the code, run the narrowest local check that reproduces it, commit (Phase 1 rules, `fix:` or `test:` as true to the change, or `style:`/`chore:` for lint/format), `git push`. Never force-push; never skip hooks or disable/WIP a test to get green.
   - **Unrelated or pre-existing** (fails the same way on the base branch, or touches code the diff does not): do not fix it inside this change. Report it in chat with the job name and the evidence.
3. Watch the new pipeline and repeat.

**Stop conditions:** pipeline green; three fix attempts on the same job without progress; a failure that needs a user decision (credentials, product behaviour, scope); or an unrelated failure. Then report in chat: PR/MR URL, which job failed, the cause, what you tried. Green: one line, nothing more.

## Guardrails

- Anything you turn up along the way (a bug, a scope question, a decision for the user) goes in chat, not into the description. That pressure is what inflates descriptions.
- Match the base branch the repo actually uses; do not assume `main`.
- Never force-push, and never push to the base branch.
- Never add `Signed-off-by`: only a human can certify the DCO.
