# Worktree isolation

Shared by `relay-feature` and `relay-implement`. Implementation happens in a **git worktree**, never the user's checkout, so several sessions can run on one repo and a half-finished change never blocks the user's `git status`.

A profile `## Worktree` section, or a worktree convention stated in `AGENTS.md` / `CLAUDE.md`, overrides every default below (base branch, branch name, directory, post-create copies, extra cleanup).

## Create

```bash
SLUG=<slug>   # lowercase, hyphens, <=30 chars, derived from the task
ROOT="$(git worktree list --porcelain | awk '/^worktree /{print substr($0,10); exit}')"   # main checkout, works from inside another worktree
BASE="$(git -C "$ROOT" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')"
BASE="${BASE:-$(git -C "$ROOT" branch --list main master --format '%(refname:short)' | head -1)}"
git -C "$ROOT" fetch --quiet origin "$BASE"      # branch off the remote tip, not a stale local copy

if [ -f "$ROOT/.wtp.yml" ] && command -v wtp >/dev/null 2>&1; then
    WORKTREE_PATH="$(cd "$ROOT" && wtp add -b "worktrees/$SLUG" --quiet)"      # applies the repo's post-create hooks
else
    WORKTREE_PATH="$ROOT/.worktrees/$SLUG"
    grep -qxF '.worktrees/' "$ROOT/.git/info/exclude" 2>/dev/null || echo '.worktrees/' >> "$ROOT/.git/info/exclude"
    git -C "$ROOT" worktree add -b "worktrees/$SLUG" "$WORKTREE_PATH" "origin/$BASE" >/dev/null
fi
echo "$WORKTREE_PATH"
```

- Branch is `worktrees/<slug>` unless the profile says otherwise; it branches off `origin/$BASE` (the default branch's remote tip). `wtp` picks its own start point; the [sync](#sync-with-the-base-branch-orchestrator-only) before review brings it current either way.
- If the branch already exists (resuming work): `git -C "$ROOT" worktree add "$WORKTREE_PATH" worktrees/$SLUG`, or `wtp add worktrees/$SLUG --quiet`.
- Capture the printed absolute path as `WORKTREE_PATH`. If creation fails, stop and report; do not fall back to the main checkout.
- The main checkout may hold uncommitted files (e.g. a fresh `.omp/relay.md`). They are **not** in the worktree. Pass what agents need through the delegation `context`, not by path.

## Work inside it

- Every `bash` call: `cwd=WORKTREE_PATH`. Every read/edit/write: an absolute path under `WORKTREE_PATH`.
- Repo wrappers (`bin/check`, `make`, `npm run`) resolve the repo root themselves; run them from inside the worktree.
- If the profile says the change may touch container/compose definitions, isolate the compose stack per the profile (usually `COMPOSE_PROJECT_NAME=<slug>`).

## Sync with the base branch (orchestrator only)

Before review, bring the branch up to date with the remote base, so the review sees the code that will actually merge, and CI or a merge bot (Atlantis, merge trains) does not hit a conflict the pipeline never saw. Work is usually uncommitted at this point; `--autostash` carries it across.

```bash
git -C "$WORKTREE_PATH" fetch --quiet origin "$BASE"
git -C "$WORKTREE_PATH" merge --autostash --no-edit "origin/$BASE"
git -C "$WORKTREE_PATH" diff --name-only --diff-filter=U    # conflicted files; must be empty
```

- Merge, not rebase, unless the profile's Delivery **Base sync** setting is `rebase` and the branch was never pushed.
- The merge exits 0 even when re-applying the autostash conflicts. The `--diff-filter=U` list is the check. Non-empty: dispatch `relay-implementer` to resolve exactly those files (keep both sides' intent; no other edits) and run the gate. Then `git -C "$WORKTREE_PATH" reset --quiet` (clears the unmerged index entries, keeps the files) and `git -C "$WORKTREE_PATH" stash drop` (the autostash entry git kept). Never `stash pop` it again.
- Branch already has commits and the merge itself conflicted (`git rev-parse -q --verify MERGE_HEAD` succeeds): after the resolution, `git add` the resolved files and `git commit --no-edit` to conclude the merge instead of `reset`; git re-applies the autostash then, and the `--diff-filter=U` check runs again.
- No new commits on the base: nothing happened, carry on.

## Snapshot (orchestrator only)

A tree object of the worktree as it is now, tracked and untracked files (ignored files excluded), without touching the index, `HEAD` or the stash. Two snapshots give the exact diff between them, which is how a re-review sees only the rework.

```bash
snap() { local idx; idx="$(mktemp -u)"; GIT_INDEX_FILE="$idx" git -C "$WORKTREE_PATH" add -A && GIT_INDEX_FILE="$idx" git -C "$WORKTREE_PATH" write-tree; rm -f "$idx"; }
snap    # prints a tree id; later: git -C "$WORKTREE_PATH" diff <earlier-id> <later-id>
```

Note each printed id in your own notes: shell variables and functions may not survive between `bash` calls, so redefine `snap` in each call that uses it.

## Cleanup (orchestrator only)

Only the orchestrator removes the worktree, and only after the user says the work is merged or abandoned. **Sub-agents never run any of this**; their work is usually uncommitted, and removal destroys it irrecoverably (no trash, no git object).

```bash
# from the main checkout
wtp remove --force <slug>                       # or: git worktree remove --force "$WORKTREE_PATH"
git branch -D "worktrees/<slug>"                # only if dropping the branch; keep it if an MR/PR is open
```

Check `git -C "$WORKTREE_PATH" status --short` first. If it is dirty and the user has not said to discard, ask.
