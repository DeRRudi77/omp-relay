---
name: relay-learn
description: "Mine the human review comments on a repo's recently merged PRs (GitHub) or MRs (GitLab) in a few batched GraphQL calls, cluster them by class, and append the recurring ones to the repo's .omp/relay.md: a Recurring review findings section, which both relay reviewers check on every diff, plus proposed Review priorities rows. Use for /relay-learn, learn from past reviews, or what do reviewers keep catching."
argument-hint: "<nothing (merged since the last run, else the last 40), a count (max 100), or a since date>"
---

Find what human reviewers keep flagging after the relay reviewers have passed a change, and write it into the profile so `relay-threat-reviewer` and `relay-consumer-reviewer` check it next time. Read-only against the forge; the only file you write is `.omp/relay.md`.

## Steps

1. **Profile.** Read `.omp/relay.md` from the main checkout's repo root. None: stop and suggest `/relay-init` first. Note the existing **Recurring review findings** entries, its `Mined through` line (the watermark), and the **Review priorities** rows.
2. **Forge and window.** Forge, owner and repo from `git remote get-url origin`. Window: the argument; else merged after the watermark date; else the last 40 merged. Page size 20 (GitLab: lower it if the API reports the query exceeds its complexity limit). Cap: 5 pages, 100 PRs/MRs, whatever the argument says.
3. **Fetch, one call per page.** Write the query to a file in a `mktemp -d` directory and send it with headers kept (`-i`), saving each response to its own file; the body starts after the first blank line. Pass `cursor` from the previous page's `endCursor` and stop at the cap or at `hasNextPage: false`. Never call the API once per PR/MR, not even to fill in a truncated thread; report truncation instead.
   - GitHub (`gh api graphql -i -f q='repo:<owner>/<repo> is:pr is:merged merged:>=<date> sort:updated-desc' -F n=20 [-F cursor=<c>] -F query=@<file>`):
     ```graphql
     query($q: String!, $n: Int!, $cursor: String) {
       rateLimit { remaining resetAt }
       search(type: ISSUE, query: $q, first: $n, after: $cursor) {
         pageInfo { hasNextPage endCursor }
         nodes { ... on PullRequest {
           number mergedAt author { login }
           reviews(first: 30) { nodes { state body author { login __typename } } }
           reviewThreads(first: 50) { totalCount nodes { path comments(first: 10) { nodes { body author { login __typename } } } } }
           comments(first: 50) { totalCount nodes { body author { login __typename } } }
         } }
       }
     }
     ```
     Without a date, drop `merged:>=<date>`; on GitLab, leave out `since`.
   - GitLab (`glab api graphql -i -F path=<group/project> -F n=20 [-f since=<iso-date>] [-F cursor=<c>] -F query=@<file>`):
     ```graphql
     query($path: ID!, $n: Int!, $cursor: String, $since: Time) {
       project(fullPath: $path) {
         mergeRequests(state: merged, sort: MERGED_AT_DESC, mergedAfter: $since, first: $n, after: $cursor) {
           pageInfo { hasNextPage endCursor }
           nodes {
             iid mergedAt author { username }
             notes(first: 100) {
               pageInfo { hasNextPage }
               nodes { system body author { username bot } position { filePath } }
             }
           }
         }
       }
     }
     ```
4. **Rate limits: stop, never retry.** HTTP 429, a 403 or GraphQL error naming a rate limit, or GitHub `rateLimit.remaining` under 100: stop fetching at once. Report the `Retry-After` / `RateLimit-Reset` / `resetAt` value and how many pages you got; work with what you have only if the user agrees. A retry loop can get the machine's IP blocked for the forge's ban window.
5. **Filter** locally from the saved files (`jq`), no more API calls. Drop: system notes; bots (`__typename` `Bot`, logins ending `[bot]`, GitLab `bot: true`); machine output from accounts the API does not flag as bots (on GitLab, tracker linkbacks, plan runners and CI reporters are ordinary users): a body that contains an HTML comment marker (`<!--`), or an account whose every comment is formulaic (`Ran Plan for ...`, a review-started banner); forge or tool commands (`plan`, `apply`, `/approve`, `/merge`, `retry`); the PR/MR author's own comments; approvals and reviews with an empty body; comments under five words or emoji only (`LGTM`, `thanks`, `+1`, `done`). Name the accounts you dropped as bots in the report.
6. **Cluster and rank.** Classify each remaining comment by what the reviewer checked, not by file (an overclaiming doc sentence, a test that survives deleting the guarded line, a trust claim missing its platform prerequisite, a job that breaks on re-run). Match existing classes first. Rank classes by the number of distinct PRs/MRs. Keep a class when at least two PRs/MRs raise it, or when one PR/MR raised it as blocking (`issue`, requested changes) and it concerns security, data loss or a crash; other singletons go in the report, not the profile.
7. **Draft the profile changes.**
   - `## Recurring review findings` (after **Review priorities**; create it if missing): first line `Mined through <#n or !n>, <YYYY-MM-DD>, from <count> merged PRs/MRs.`, replacing the old watermark line. Then one bullet per class, most frequent first: `- **<Class>.** <what to check, imperative>. Examples: <paraphrase> (<#n>); <paraphrase> (<#n>).`
   - **Append, never rewrite.** An existing class keeps its wording; add only new PR/MR numbers to its bullet. New classes go after the existing ones.
   - **Review priorities**: propose a row for each new class no row covers, with a severity. Never lower or remove an existing row.
   - Paraphrase every example in at most ~15 words. Never copy a full comment body, and never write secrets, tokens, credentials, account IDs or hostnames from a comment into the profile. No reviewer names or per-person counts.
8. **Confirm** (`ask`): show the new bullets and the proposed rows with their severities (severity is judgment, so pre-fill your guess). Write only what the user accepts.
9. **Write** `.omp/relay.md` and report: window and PRs/MRs read, pages fetched, threads truncated, accounts dropped as bots, classes added or extended, singletons left out. Do **not** commit; the user decides whether the profile is tracked.
