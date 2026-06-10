#!/usr/bin/env bash
# Block `git push --force`/`-f` (not --force-with-lease) when the target
# branch is main or master. If a branch is explicit, check that; otherwise
# fall back to the current branch.
payload=$(cat)
cmd=$(printf '%s' "$payload" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null)
[ -z "$cmd" ] && cmd=$(printf '%s' "$payload" | python -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null)
[ -z "$cmd" ] && exit 0

# Extract the `git push ...` segment (stop at shell separators).
push_seg=$(printf '%s' "$cmd" | grep -oE '(^|[[:space:]])git[[:space:]]+push[^|;&]*' | head -n1)
[ -z "$push_seg" ] && exit 0

san=$(printf '%s' "$push_seg" | sed 's/--force-with-lease//g')
echo "$san" | grep -qE '(--force([^a-z-]|$)|(^|[[:space:]])-f([[:space:]]|$))' || exit 0

# Tokenize: drop "git push", keep positionals (non-flag tokens).
read -r -a toks <<<"$push_seg"
positionals=()
skip=2  # drop "git" and "push"
for t in "${toks[@]}"; do
  if [ $skip -gt 0 ]; then skip=$((skip-1)); continue; fi
  case "$t" in
    -*) ;;
    *) positionals+=("$t") ;;
  esac
done

tgt=""
# positionals = [remote, refspec...]; refspecs start at index 1.
if [ ${#positionals[@]} -ge 2 ]; then
  for refspec in "${positionals[@]:1}"; do
    # For src:dst refspecs the destination is what gets rewritten — use the
    # right side. Otherwise the whole token is both source and destination.
    if [[ "$refspec" == *:* ]]; then
      dst=${refspec#*:}
    else
      dst=$refspec
    fi
    case "$dst" in
      main|master) tgt="explicit=$dst"; break ;;
    esac
  done
else
  br=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
  case "$br" in main|master) tgt="current=$br";; esac
fi

[ -z "$tgt" ] && exit 0
printf 'Blocked: force-push to main/master (%s). Run outside Claude (type ! <cmd>) if intentional.\n' "$tgt" >&2
exit 2
