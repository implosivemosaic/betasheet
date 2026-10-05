#!/usr/bin/env bash
# Apply a run's approved proposals to the dev database or production.
# Usage: research/apply.sh dev|prod [RUN_DIR]
# Prod needs FLY_API_TOKEN (the box's workspace Fly connection). Results append to RUN_DIR/applied.json;
# entries a target already applied are skipped, so re-running after a fix never adds a listing twice.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd); repo=$(dirname "$here")
target=${1:?usage: $0 dev|prod [RUN_DIR]}
run=${2:-$(ls -d "$repo/../betasheet-data/betasheet/runs/20"* | tail -1)}

all=$(python3 "$here/apply_select.py" "$run" "$target")
[ "$all" = "[]" ] && { echo "nothing to apply"; exit 0; }
script=$(gzip -9c "$here/apply.exs" | base64 -w0)
count=$(printf '%s' "$all" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')

# Fly's machine exec API rejects large commands, so entries go over in batches.
for start in $(seq 0 25 $((count - 1))); do
  todo=$(printf '%s' "$all" | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin)[$start:$start + 25]))")
  payload=$(printf '%s' "$todo" | gzip -9c | base64 -w0)
  # No spaces: machine exec splits its command on them.
  code="Process.put(:proposals,:zlib.gunzip(Base.decode64!(~S|$payload|)));Code.eval_string(:zlib.gunzip(Base.decode64!(~S|$script|)))"

  case $target in
    dev)
      out=$(cd "$repo" && env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root TERM=dumb \
        MIX_ENV=dev LANG=C.UTF-8 ELIXIR_ERL_OPTIONS="+fnu" mix run -e "$code" 2>&1) ;;
    prod)
      flyctl agent stop >/dev/null 2>&1 || true   # a hung local agent makes flyctl reject valid tokens
      out=$(flyctl machine exec 874227b0321039 "/app/bin/climb_ontario rpc $code" -a climb-ontario-keith -t "$FLY_API_TOKEN" 2>&1) ;;
    *) echo "usage: $0 dev|prod [RUN_DIR]" >&2; exit 2 ;;
  esac

  printf '%s\n' "$out" | sed -n 's/^APPLIED //p' > "$run/.applied-lines"
  [ -s "$run/.applied-lines" ] || { rm -f "$run/.applied-lines"; printf '%s\n' "$out" >&2; exit 1; }
  python3 "$here/apply_record.py" "$run" "$target" "$run/.applied-lines"
  rm -f "$run/.applied-lines"
done
