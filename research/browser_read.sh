#!/usr/bin/env bash
# Read a page through Keith's logged-in desktop browser (Instagram, Facebook). Prints the page's
# readable text, then the post/reel links it shows. Calls are serialized with a lock, because every
# researcher shares the one browser tab reserved for research.
# Usage: research/browser_read.sh URL [SECONDS_TO_WAIT]
# Needs: lego browser connect --port 9013 (once per box session). Tab: $BETASHEET_TAB (default 4),
# a tab the research tool opened, never one of Keith's own tabs.
set -euo pipefail
url=$1; wait=${2:-5}; tab=${BETASHEET_TAB:-4}
exec 9>/tmp/betasheet-browser.lock
flock -w 600 9
out=$(mktemp)
lego browser call navigate "{\"page\":$tab,\"url\":\"$url\"}" >/dev/null
sleep "$wait"
{ lego browser call read "{\"page\":$tab}" 2>/dev/null || lego browser call snapshot "{\"page\":$tab}"
  echo
  echo "== post links =="
  lego browser call evaluate "{\"page\":$tab,\"func\":\"() => [...new Set([...document.querySelectorAll('a')].map(a=>a.href).filter(h=>/\\\\/(p|reel|events)\\\\//.test(h)))].join('\\\\n')\"}" | grep -E '/(p|reel|events)/' || true
} > "$out"
sleep 2   # spacing between calls, so the account isn't hammered
# A dropped session or tool error comes back as a short error line, not a page: fail loudly.
if grep -qE '^(error|Error):|no browser session' "$out" || [ "$(wc -c < "$out")" -lt 300 ]; then
  cat "$out" >&2; rm -f "$out"
  echo "browser read failed; run: lego browser connect --port 9013, then retry" >&2; exit 1
fi
# Drop the tool's per-call wrapper lines (random nonce, truncation notes, tips) so the
# fingerprint only changes when the page does.
grep -vE 'UNTRUSTED_PAGE_CONTENT|Content truncated|saved to /Users/|^Tip: |^--- Additional context' "$out"
rm -f "$out"
