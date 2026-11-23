# Bound-issue segment for a session the development workflow has bound to an
# issue. MARKERS lists the session's marker files; each holds the issue's absolute
# path, and anything else means the session is not bound.
#
# Emits the issue segment and the mode fact: the issue's workflow.mode, which
# records changes to the session's autonomy made after launch.

issue_mode() {  # ISSUE — prints workflow.mode from the front matter, or nothing
  [[ -r $1 ]] || return 0
  awk '
    NR == 1 { if ($0 != "---") exit; next }
    $0 == "---" { exit }
    /^workflow:[[:space:]]*$/ { wf = 1; next }
    wf && /^[^[:space:]]/ { exit }
    wf && match($0, /^[[:space:]]+/) {
      if (!indent) indent = RLENGTH
      if (RLENGTH == indent && $0 ~ /^[[:space:]]+mode:/) {
        v = $0
        sub(/^[[:space:]]+mode:[[:space:]]*/, "", v)
        sub(/[[:space:]]*#.*$/, "", v)
        gsub(/["\047]/, "", v)
        print v
        exit
      }
    }
  ' $1
}

read -r issue < $MARKERS[1]
[[ $issue == /* ]] || return 0
slug=${${issue:t:r}#<->-}
if [[ -n $slug ]]; then
  emit seg issue $C_ISSUE 2 \
    "$I_ISSUE $(ellipsize $slug 48)" "$I_ISSUE $(ellipsize $slug 28)" "$I_ISSUE $(ellipsize $slug 18)"
fi
mode=$(issue_mode $issue)
[[ $mode != (autonomous|interactive) ]] || emit fact mode $mode
