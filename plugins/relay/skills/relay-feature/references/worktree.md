# Worktree isolation

Shared by `relay-feature` and `relay-implement`. Implementation happens in a **git worktree**, never the user's checkout, so several sessions can run on one repo and a half-finished change never blocks the user's `git status`.

A profile `## Worktree` section, or a worktree convention stated in `AGENTS.md` / `CLAUDE.md`, overrides every default below (base branch, branch name, directory, post-create copies, extra cleanup).

## Create

```bash
SLUG=<slug>   # lowercase, hyphens, <=30 chars, derived from the task
ROOT="$(git worktree list --porcelain | awk '/^worktree /{print substr($0,10); exit}')"   # main checkout, works from inside another worktree
BASE="$(git -C "$ROOT" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')"
BASE="${BASE:-$(git -C "$ROOT" branch --list main master --format '%(refname:short)' | head -1)}"

if [ -f "$ROOT/.wtp.yml" ] && command -v wtp >/dev/null 2>&1; then
    WORKTREE_PATH="$(cd "$ROOT" && wtp add -b "worktrees/$SLUG" --quiet)"      # applies the repo's post-create hooks
else
    WORKTREE_PATH="$ROOT/.worktrees/$SLUG"
    grep -qxF '.worktrees/' "$ROOT/.git/info/exclude" 2>/dev/null || echo '.worktrees/' >> "$ROOT/.git/info/exclude"
    git -C "$ROOT" worktree add -b "worktrees/$SLUG" "$WORKTREE_PATH" "$BASE" >/dev/null
fi
echo "$WORKTREE_PATH"
```

- Branch is `worktrees/<slug>` unless the profile says otherwise; it branches off `$BASE` (the default branch).
- If the branch already exists (resuming work): `git -C "$ROOT" worktree add "$WORKTREE_PATH" worktrees/$SLUG`, or `wtp add worktrees/$SLUG --quiet`.
- Capture the printed absolute path as `WORKTREE_PATH`. If creation fails, stop and report; do not fall back to the main checkout.
- The main checkout may hold uncommitted files (e.g. a fresh `.omp/relay.md`). They are **not** in the worktree. Pass what agents need through the delegation `context`, not by path.

## Work inside it

- Every `bash` call: `cwd=WORKTREE_PATH`. Every read/edit/write: an absolute path under `WORKTREE_PATH`.
- Repo wrappers (`bin/check`, `make`, `npm run`) resolve the repo root themselves; run them from inside the worktree.
- If the profile says the change may touch container/compose definitions, isolate the compose stack per the profile (usually `COMPOSE_PROJECT_NAME=<slug>`).

## Cleanup (orchestrator only)

Only the orchestrator removes the worktree, and only after the user says the work is merged or abandoned. **Sub-agents never run any of this**; their work is usually uncommitted, and removal destroys it irrecoverably (no trash, no git object).

```bash
# from the main checkout
wtp remove --force <slug>                       # or: git worktree remove --force "$WORKTREE_PATH"
git branch -D "worktrees/<slug>"                # only if dropping the branch; keep it if an MR/PR is open
```

Check `git -C "$WORKTREE_PATH" status --short` first. If it is dirty and the user has not said to discard, ask.
