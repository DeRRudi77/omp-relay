---
name: relay-commit
description: "Commit the current work as short Conventional Commits, push a topic branch, and open a pull request (GitHub) or merge request (GitLab, Gitea, Bitbucket, ...) on whatever forge the repo uses, then watch its pipeline and, when the repo enables it, post a review request to Slack. Replaces forge-specific commit-and-pr / commit-and-mr skills. Use for /relay-commit, commit and PR, commit and MR, open a PR/MR, or ship this. Reads the repo's Delivery settings from .omp/relay.md or AGENTS.md / CLAUDE.md. Keeps commit messages and descriptions short."
argument-hint: "<optional: notes for the description, or a ticket key>"
---

Phases: **commit**, **publish**, **watch the pipeline**, and, when the repo turns it on, **request review** in Slack. All are governed by one rule, and all take their settings from the repo.

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
| **Base sync** | `merge`: a branch behind `origin/<base>` merges it before push (Publish step 2). `rebase` rebases instead, for branches never pushed |
| **PR/MR recipe** | an exact command; replaces step 5 of Publish entirely |
| **Attribution** | an `Assisted-by` commit trailer plus a PR/MR footer; `pr-only`, `none` or a repo-specified trailer change that, as in [Attribution](#attribution) |
| **Prose pass** | none; if the setting names a skill (e.g. `humanizer`), run commit subjects/bodies and the PR/MR title/description through it after shortening, preserving syntax, issue references, commands, code blocks and facts |
| **CI watch** | `on`: after opening the PR/MR, watch its pipeline and fix failures (Phase 3). `off` skips it |
| **Review request** | `off`. A Slack channel turns it on: after publishing, post a review request there (Phase 4). Optional `cc:`, `format:` and `sign-off:` parts, as in [Phase 4](#phase-4-request-review) |

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
2. If the user asked only to "commit" (and no calling skill passed approval), stop after Phase 1 and ask first. Otherwise check the branch contains the current base: `git fetch origin <base>`, then `git merge-base --is-ancestor origin/<base> HEAD`. If it does not, bring it current per the **Base sync** setting, run the gate, and only then push. A conflict you cannot resolve without guessing at intent: stop and report the files. CI and merge bots (Atlantis, merge trains) test the merged result, so a stale branch fails there instead of here.
3. `git push -u origin <branch>`.
4. If the repo has a PR/MR template (`.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE/`, `.gitlab/merge_request_templates/`), follow its sections exactly but fill them tersely; `N/A` is a complete answer.
5. Open the request:
   - **A configured PR/MR recipe replaces everything below.** Run it.
   - Otherwise pick the forge from `git remote get-url origin`: GitHub → `gh pr create`; GitLab → `glab mr create`; Gitea/Forgejo → a mounted Gitea MCP's create-pull-request, if any; anything else → the API tool the user has, or the "create pull request" URL that `git push` prints.
   - **If the CLI fails** (not installed, not authenticated, or `glab` rejecting the remote because `~/.ssh/config` rewrites the host), use the forge's API instead of fighting it: `gh api -X POST repos/<owner>/<repo>/pulls -f head=<branch> -f base=<base> -f title=... -f body=...`, or `glab api -X POST "projects/<url-encoded-path>/merge_requests" -f source_branch=<branch> -f target_branch=<base> -f title=... -f description=...` (`%2F` for each `/` in the path). Pass multi-line bodies through a heredoc into a variable. Tell the user which path you took.
6. Title: the lead commit's subject, or one line spanning the commits. Description: the why, then a short bullet list. Include whatever the calling skill required.
7. Link the ticket if there is one: a key in the branch name or commits, or one the caller passed. Fetch its title or URL only if you need it, using the tools the repo's `## Tracker` section names (`skill://relay-feature/references/tracker.md`). No ticket, no line; never invent a reference.
8. End the description with the attribution footer, when the setting calls for one ([Attribution](#attribution)).
9. Report the PR/MR URL, then go to Phase 3. Mention the pipeline only if it is the first run of a new job or expected to fail.

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

**Stop conditions:** pipeline green; three fix attempts on the same job without progress; a failure that needs a user decision (credentials, product behaviour, scope); or an unrelated failure. Then report in chat: PR/MR URL, which job failed, the cause, what you tried. Green: one line, then Phase 4.

## Phase 4: Request review

Only when the **Review request** setting names a channel; it is off by default. Post once, when this run opened the PR/MR: a run that pushed to an existing one does not post again. Post after Phase 3 ends green, or right after opening when Phase 3 was skipped. A red pipeline means no post; say so in chat, since reviewers should not be asked to look at a failing change.

The setting is the channel, then optional parts separated by `;`:

```
- **Review request**: https://<workspace>.slack.com/archives/C0123456789; cc: <@U0123ABCD> <!subteam^S0123ABCD>; sign-off: :zap: :coffee: :pray:
```

- **Channel**: an archive URL (the ID is the segment after `/archives/`), a channel ID, or `#name` (look it up with the Slack MCP's channel search).
- **cc** (optional): Slack mentions, `<@U…>` for people and `<!subteam^S…>` for groups. Resolve a plain name with the Slack MCP's user search; leave out any you cannot match to exactly one person, and say so in chat.
- **format** (optional): the first line, with `{url}` for the PR/MR URL and `{sign-off}` for the sign-off emoji. Default `:request-review: {url} {sign-off}`. `:request-review:` is a custom emoji, so a workspace without it needs its own format.
- **sign-off** (optional): the emoji to pick from, space-separated, or `none`. Default: `:please-minion: :yes-please: :thankyoubow: :thankyou-rainbow: :keanu-thanks: :pikachu-thanks: :catcoding: :bongocat_code: :cat-on-keyboard: :coffee: :zap:`. Most of these are custom emoji too. Pick one per post, by the change, from those in the list:
  - `:zap:` a small change (roughly 30 changed lines or fewer); `:cat-on-keyboard:` when that small change is a fix, typo or cleanup.
  - `:coffee:` a large one (roughly 400+ changed lines, or one that needs a sitting to review).
  - `:catcoding:` / `:bongocat_code:` mostly code, between those sizes.
  - Otherwise any of the please/thank-you ones, varying between posts.
  - A custom list without these names: pick any one, varying between posts.

The message:

```
:request-review: https://gitlab.example.com/group/project/-/merge_requests/216 :catcoding:
Moves review snapshots to the metrics bucket so every development agent shows on the quality page. Config and IAM only.
cc: <@U0123ABCD> <!subteam^S0123ABCD>
```

1. Line 1: the format, with the URL and sign-off filled in. With `sign-off: none`, drop `{sign-off}` and the space before it.
2. Line 2, always: a short description of the change, written for someone deciding whether to open the link. One to three sentences, at most ~60 words: what changes and why, plus a merge-order dependency or deploy step if there is one. Write it from the PR/MR's why paragraph, not as a copy of the description. Slack mrkdwn, not Markdown: no headings, no tables; backticks are fine. No open review findings, no attribution footer. Run it through the **Prose pass** skill when one is set.
3. Line 3, only when `cc` is set: `cc: ` and the mentions.
4. Send it with the mounted Slack MCP's send-message tool, using the channel ID. There is no Slack MCP or the send fails: do not try another route. Put the message in chat for the user to post.
5. Report the message permalink in one line.

## Guardrails

- Anything you turn up along the way (a bug, a scope question, a decision for the user) goes in chat, not into the description or the Slack message. That pressure is what inflates descriptions.
- Match the base branch the repo actually uses; do not assume `main`.
- Never force-push, and never push to the base branch.
- Never add `Signed-off-by`: only a human can certify the DCO.
