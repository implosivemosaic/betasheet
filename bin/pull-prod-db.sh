#!/usr/bin/env bash
# Copies the production catalogue into the betasheet-data repo as a dated snapshot.
# Usage: FLY_API_TOKEN=... bin/pull-prod-db.sh [path-to-betasheet-data]
set -euo pipefail
data="${1:-$(dirname "$0")/../../betasheet-data}"
dest="$data/betasheet/snapshots/catalogue-$(date -u +%Y%m%dT%H%M%SZ).sqlite"
mkdir -p "$(dirname "$dest")"
flyctl ssh sftp get /data/catalogue.db "$dest" -a climb-ontario-keith >/dev/null
chmod 600 "$dest"
python3 - "$dest" <<'PY'
import sqlite3, sys
c = sqlite3.connect(sys.argv[1])
print(sys.argv[1], "|", c.execute("pragma integrity_check").fetchone()[0], "| listings", c.execute("select count(*) from listings").fetchone()[0], "| occurrences", c.execute("select count(*) from occurrences").fetchone()[0])
PY
