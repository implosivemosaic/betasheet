#!/usr/bin/env bash
# Copies the production catalogue into the betasheet-data repo as a dated snapshot.
# Takes a consistent copy on the Machine first (VACUUM INTO), so recent writes still in
# SQLite's write-ahead log are included, then downloads it and removes the temporary copy.
# Usage: FLY_API_TOKEN=... bin/pull-prod-db.sh [path-to-betasheet-data]
set -euo pipefail
data="${1:-$(dirname "$0")/../../betasheet-data}"
stamp=$(date -u +%Y%m%dT%H%M%SZ)
dest="$data/betasheet/snapshots/catalogue-$stamp.sqlite"
tmp="/data/snapshot-$stamp.sqlite"
mkdir -p "$(dirname "$dest")"
fly() { flyctl "$@" -a climb-ontario-keith -t "$FLY_API_TOKEN"; }
flyctl agent stop >/dev/null 2>&1 || true   # a hung local agent makes flyctl reject valid tokens
# machine exec splits its command on spaces, so the Elixir goes over base64-encoded.
code=$(printf "ClimbOntario.Repo.query!(\"VACUUM INTO '%s'\")" "$tmp" | base64 -w0)
fly machine exec 874227b0321039 "/app/bin/climb_ontario rpc Code.eval_string(Base.decode64!(~S|$code|))" >/dev/null
fly ssh sftp get "$tmp" "$dest" >/dev/null
fly machine exec 874227b0321039 "rm -f $tmp" >/dev/null
chmod 600 "$dest"
python3 - "$dest" <<'PY'
import sqlite3, sys
c = sqlite3.connect(sys.argv[1])
print(sys.argv[1], "|", c.execute("pragma integrity_check").fetchone()[0], "| listings", c.execute("select count(*) from listings").fetchone()[0], "| occurrences", c.execute("select count(*) from occurrences").fetchone()[0])
PY
