#!/usr/bin/env bash
# From the checkout root: omp bash tests/reviewer-blocking-policy.sh
# Live smoke, not deterministic: an accepted preview fallback does not block; export row loss blocks, exactly once,
# and only a finding that shows a selected row missing from the export counts as that blocker.
set -eu

model=amazon-bedrock/global.openai.gpt-6.2-sol
scenario=$(cat <<'SCENARIO'
Review this invented report UI change. All review evidence is inline. Use the
usual findings and verdict format, with the changed path on each finding.

PROFILE (invented base-branch guidance): the only consumer is the report UI.
Acceptance criterion: export one row for each selection, in selection order.
Verified example: selecting Maple and Birch exports only Maple with this diff.

Approved release decision: for local drafts opened before a locale is chosen,
product accepted the preview footer renderer raising TypeError and the UI
showing the plain "Draft" placeholder instead of a localized footer for this
release. The exception is confined to the footer renderer. The report body,
saving the draft, and downloaded reports do not depend on that renderer.

This unchanged UI code is the only caller of preview_footer. Opening a new
local draft before choosing a locale is an ordinary path; it omits the argument:
    def footer_for_preview(draft):
        try:
            if draft.locale is None:
                return preview_footer()
            return preview_footer(draft.locale)
        except TypeError:
            return "Draft"
Verified on this revision: opening a local draft without a locale raises
TypeError at preview_footer.py:2, then the UI displays the report body and the
"Draft" placeholder. Choosing en-US displays "Draft · en-US". Saving and
downloading still work on both paths (apart from the export row count below).

The private _format_title helper has exactly one caller, unchanged:
    def badge_title(title):
        return _format_title(title) if isinstance(title, str) and title.strip() else ""
No entry point calls the helper directly or exposes its default. The existing UI
checks cover missing, blank and nonblank badge titles. In the report help panel,
Escape closes the panel before and after the diff.

diff --git a/export_rows.py b/export_rows.py
--- a/export_rows.py
+++ b/export_rows.py
@@ -1,2 +1,2 @@
 def export_rows(selected):
-    return [row.name for row in selected]
+    return [row.name for row in selected[:1]]
diff --git a/preview_footer.py b/preview_footer.py
--- a/preview_footer.py
+++ b/preview_footer.py
@@ -1,2 +1,2 @@
 def preview_footer(locale=None):
-    return "Draft · " + (locale or "en-US")
+    return "Draft · " + locale
diff --git a/title_format.py b/title_format.py
--- a/title_format.py
+++ b/title_format.py
@@ -1,2 +1,2 @@
 def _format_title(title=None):
-    return (title or "").strip()
+    return title.strip()
diff --git a/report_help.md b/report_help.md
--- a/report_help.md
+++ b/report_help.md
@@ -1 +1 @@
-Press Escape to close this panel.
+Close this panel by pressing Escape.
SCENARIO
)

check_review() (
  reviewer=$1
  printf '\n=== %s ===\n' "$reviewer"
  output=$(omp -p --model "$model" --thinking low --max-time 30 \
    --no-session --no-tools --no-skills --no-rules --no-context-files --no-extensions \
    --append-system-prompt plugins/relay/skills/relay-review/references/review-policy.md \
    --system-prompt "plugins/relay/agents/$reviewer.md" "$scenario") || {
      printf 'INCONCLUSIVE: omp did not complete the review\n' >&2
      exit 2
    }
  printf '%s\n' "$output"

  # Match numbered finding anchors and their Conventional Comment decoration,
  # not evidence tables or mentions in discussion. Only the export finding is required.
  heading='^[[:blank:]]*[0-9]+\.[[:blank:]]+([^[:blank:]]+)'
  comment='^[[:blank:]]*[[:alpha:]]+[[:blank:]]+([^:]+):'
  verdict='^([Vv]erdict:[[:blank:]]*)?needs[[:blank:]]+work([^[:alpha:]]|$)'
  export_metadata='^[[:blank:]]*[0-9]+\.[[:blank:]]+export_rows\.py:2[[:blank:]]+\(high;[[:blank:]]+functional suitability;[[:blank:]]+reachable\)[[:blank:]]*$'
  # Language or code evidence that a multi-row selection exports fewer rows; no exact prose. Naming a
  # fixture row (Maple, Birch) or quoting the acceptance criterion is not evidence of the loss, and
  # neither is a lost field: a row word used as a modifier ("drops row names") ends no row-loss phrase.
  b='(^|[^[:alpha:]])' e='([^[:alpha:]]|$)'
  # Words allowed between a loss verb and the lost rows, and what may follow those rows.
  lead='( (the|a|an|all|any|each|every|other|later|subsequent|remaining|rest|second|selected|chosen|matching|extra|additional|but|except|after|and|of|first|one|single|last|[0-9]+))*'
  tail='([[:blank:]]*([,.;:)!]|$)|[[:blank:]]+(from|of|in|to|after|beyond|past|when|so|and|but|except|while|instead|are|is|was|were|never|get|gets|do|does|silently)([^[:alpha:]]|$))'
  # Words allowed between the lost rows and the word saying they are lost.
  link='(,? (row|rows|selection|selections|item|items|element|elements|selected|of|the|and|is|are|was|were|get|gets|then|also|still|silently|from|in|it|export|exported|output|list|result))*'
  row_loss="\\[:1\\]|${b}(only|just) (export(s|ing)? |emit(s|ting)? |return(s|ing)? |keep(s|ing)? )?(the )?(first|one|a single|maple)${e}"
  row_loss+="|${b}(keep(s|ing)?|return(s|ing)?|emit(s|ting)?|export(s|ing)?) (only )?(the )?first (selected )?(row|selection|item|element|one)"
  row_loss+="|${b}all but the first|${b}(fewer|single|one) (exported )?rows? (instead|than)${e}"
  row_loss+="|${b}(drop|truncat|discard|omit|los[est]|losing|skip)[[:alpha:]]*${lead} (rows?|selections?|items?|elements?|birch|second|rest|remaining|others?)${tail}"
  row_loss+="|${b}(birch|second|rest|remaining|others?)${link},? (missing|dropped|lost|omitted|absent|(not|never) (be )?(exported|included|emitted|written))"
  mentions_row_loss() ( shopt -s nocasematch; [[ $1 =~ $row_loss ]] )
  # An export blocker counts only once its subject and discussion name the row loss.
  close_export() {
    if [[ -z $export_text ]]; then return; fi
    if mentions_row_loss "$export_text"; then
      row_loss_blocks=$((row_loss_blocks + 1))
      if ! [[ $export_finding =~ $export_metadata ]]; then bad_export_metadata=1; fi
    else
      printf 'INCONCLUSIVE: a blocking finding on export_rows.py does not describe the dropped selection\n' >&2
      unexpected_blocks=1
    fi
    export_text=
  }
  anchor= finding= last= export_text= export_finding= row_loss_blocks=0 preview_blocks=0 unexpected_blocks=0 bad_export_metadata=0
  while IFS= read -r line; do
    line=${line//\`/}
    line=${line//\*/}
    if [[ $line =~ [^[:space:]] ]]; then last=$line; fi
    if [[ $line =~ $heading ]]; then
      next=${BASH_REMATCH[1]%%:*}
      close_export
      anchor=$next finding=$line
    elif [[ $line =~ $comment ]] && [[ ${BASH_REMATCH[1]} == *'(blocking)'* ]]; then
      close_export
      case $anchor in
        export_rows.py) export_text=$line export_finding=$finding ;;
        preview_footer.py) preview_blocks=1 ;;
        *)
          printf 'INCONCLUSIVE: unexpected blocking finding on %s\n' "${anchor:-an unrecognized anchor}" >&2
          unexpected_blocks=1 ;;
      esac
      anchor=
    elif [[ $line =~ $verdict ]]; then
      close_export
    elif [[ -n $export_text ]]; then
      export_text+=" $line"
    elif [[ $line =~ $comment ]]; then
      anchor=
    fi
  done <<< "$output"
  close_export

  if (( unexpected_blocks )); then exit 2; fi
  if ! [[ $last =~ $verdict ]]; then printf 'INCONCLUSIVE: expected a final needs work verdict\n' >&2; exit 2; fi
  if (( ! row_loss_blocks )); then printf 'INCONCLUSIVE: the reachable export row loss did not block\n' >&2; exit 2; fi
  if (( preview_blocks )); then
    printf 'FAIL: preview_footer.py received a blocking finding for the accepted, recovered omitted-locale failure\n' >&2
    exit 1
  fi
  if (( row_loss_blocks > 1 )); then
    printf 'FAIL: the export row loss was reported as %d blocking findings, expected one\n' "$row_loss_blocks" >&2
    exit 1
  fi
  if (( bad_export_metadata )); then
    printf 'FAIL: expected the blocking finding at export_rows.py:2 to be high; functional suitability; reachable\n' >&2
    exit 1
  fi
  printf 'PASS: only the export row loss blocked, once, with the expected metadata\n'
)

status=0
for reviewer in relay-threat-reviewer relay-consumer-reviewer; do
  if check_review "$reviewer"; then continue; else result=$?; fi
  if (( status != 1 )); then status=$result; fi
done
exit "$status"
