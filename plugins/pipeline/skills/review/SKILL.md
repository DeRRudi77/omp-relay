---
name: review
description: "Review a diff, branch, worktree, file, or a GitHub PR / GitLab MR via the diff-reviewer agent in any repo: blast radius, untested behaviour, config/schema/doc drift, correctness, security. Severity-ranked, written as Conventional Comments; on a PR/MR the comments are placed inline on the diff. Use for /review, review this diff, or review this MR/PR (URL or number)."
argument-hint: "<nothing (current diff vs default branch), a branch / worktree path / file, or a PR/MR URL or number>"
---

Dispatch the **diff-reviewer** agent on the target in the `User:` text.

## Steps

1. **Resolve the target.**
   - Empty → current diff vs the default branch (`git diff <base>...HEAD` plus `git status`).
   - A branch, worktree path, or file → that. For a worktree, pass its absolute path and say every `cwd` must be there.
   - A **PR/MR** (URL, `#123` / `!123`, or `pr://` / `mr://`) → see "Reviewing a PR/MR" below.
2. **Guidance.** Resolve `PROFILE` as in `skill://feature/SKILL.md` ("Project guidance"): `.omp/pipeline.md` if present, else `AGENTS.md` and/or `CLAUDE.md`. For a PR/MR, read it from the PR/MR's **base** branch, not the author's head. Pass it verbatim in `context` so the reviewer applies this repo's rules. None: the reviewer uses its generic priorities.
3. **Dispatch** with `task` (`agent: diff-reviewer`, with a `solutionSpace` like `review defects open; no known bug`). Do not review inline. Tell it the findings must be Conventional Comments (its output format already requires this).
4. **Relay the findings verbatim**, most severe first, with the agent's one-line verdict. For a PR/MR, continue to "Placing the comments".
5. **Offer follow-ups, do not perform them.** Ask before routing blocking findings to the **implementer**, missing coverage to the **test-writer**, or doc drift to **docs-sync**. On someone else's PR/MR there is nothing to route: the comments are the deliverable.

The reviewer never edits code. Fixes are a separate, explicit step.

## Reviewing a PR/MR

- Identify forge, repo, number and the head SHA: `gh pr view <n> --json number,headRefOid,baseRefName,url` or `glab mr view <n>` / `glab api projects/<url-encoded-path>/merge_requests/<iid>`. Take the URL's host, not the local `origin`, when they differ.
- Get the diff with `gh pr diff <n>` / `glab mr diff <n>` (or `pr://<n>/diff`, `mr://.../diff/all`). Existing review threads: read them first so you do not repeat what is already said.
- The reviewer needs the code at the PR/MR head, not your checkout. Create a throwaway detached worktree at the head SHA (`git fetch origin <ref>` then `git worktree add --detach <path> <sha>`; GitHub: `refs/pull/<n>/head`, GitLab: `refs/merge-requests/<iid>/head`), pass its path as `WORKTREE_PATH`, and remove it when done (the reviewer never touches it). If the repo is not the cwd's repo, say so and review from the diff alone, stating that limit.

## Placing the comments (PR/MR only)

Findings go on the PR/MR as **inline comments on the diff lines**, each one a Conventional Comment: `<label> [decorations]: <subject>`, a blank line, then the discussion. Always this format; no free-form comments, no severity words, no "finding N" references.

1. **Map each finding to the diff.** A finding anchors inline only if its `path:line` is a line present in the diff (an added or context line on the new side; `old:` lines on the old side). Findings with no line, or on lines outside the diff hunks, cannot be inline: put them in the review's summary body, in the same Conventional Comment format, prefixed with their `path` in backticks.
2. **Show the user the comments and the verdict, then confirm once** (`ask`) before posting. Posting is visible to the author and others and cannot be fully taken back. Offer post / edit / don't post. If the user said to post, skip the question.
3. **Post as one review, not many loose comments.**
   - **GitHub:** one call that creates a review with all inline comments, event `COMMENT` (never `APPROVE` or `REQUEST_CHANGES` unless the user says so):
     ```bash
     gh api -X POST repos/<owner>/<repo>/pulls/<n>/reviews --input review.json
     # {"commit_id": "<head sha>", "event": "COMMENT", "body": "<summary>",
     #  "comments": [{"path": "...", "line": 42, "side": "RIGHT", "body": "issue (blocking): ..."}]}
     ```
     Write the JSON to a temp file with a heredoc; never interpolate comment text into shell arguments. If the API rejects a comment (HTTP 422, line not in the diff), move that finding to the summary body and retry once.
   - **GitLab:** one discussion per inline comment, positioned on the diff. Fetch `diff_refs` (`base_sha`, `start_sha`, `head_sha`) from `merge_requests/<iid>/versions`, then `glab api -X POST projects/<path>/merge_requests/<iid>/discussions` with `position[position_type]=text`, `position[base_sha]`, `position[start_sha]`, `position[head_sha]`, `position[new_path]`, `position[old_path]`, `position[new_line]` (or `old_line`) and `body`. Post the summary as a plain MR note. Prefer drafts (`.../draft_notes`, then `.../draft_notes/bulk_publish`) so the author is notified once, if the instance supports them.
   - Other forges: use the API tool the user has; if none, give the comments as text with their `path:line`, and say why.
4. **Never approve, request changes, merge, or resolve threads** on your own initiative. The verdict (`ship` / `needs work`) is stated in the summary body as text; the user decides about forge-level approval.
5. Report the review URL (or the failures) and how many comments went inline versus into the summary.

Reviewing local changes (no PR/MR) produces the same Conventional Comments in chat only; nothing is posted.
