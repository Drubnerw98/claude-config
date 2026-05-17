#!/usr/bin/env bash
cmd=$(python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null)
echo "$cmd" | grep -qE '(^|[[:space:]])git[[:space:]]+commit\b.*[[:space:]]--amend([[:space:]]|=|$)' || exit 0
git rev-parse '@{u}' >/dev/null 2>&1 || exit 0
if git merge-base --is-ancestor HEAD '@{u}' 2>/dev/null; then
  h=$(git rev-parse --short HEAD)
  r=$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null)
  printf 'Blocked: HEAD (%s) is already pushed to %s. Amending would rewrite published history. Make a new commit on top instead.\n' "$h" "$r" >&2
  exit 2
fi
exit 0
