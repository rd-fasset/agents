#!/bin/bash
# scheduled.sh: what launchd runs. Starts update.sh only if no full run has finished since the most
# recent Monday 10:00, so the Monday trigger, login and wake-after-a-missed-Monday all collapse into
# one run a week. Posts a macOS notification with the outcome.
#
#   scheduled.sh [--check]   --check prints whether a run is due and exits

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="$HERE/logs/.last-run"

due="$(date -v-mon -v10H -v0M -v0S +%s)"
[ "$(date +%s)" -lt "$due" ] && due="$(date -v-mon -v-7d -v10H -v0M -v0S +%s)"
last="$(cat "$STATE" 2>/dev/null || echo 0)"

if [ "$last" -ge "$due" ]; then
  [ "${1:-}" = --check ] && echo "not due: last full run $(date -r "$last" '+%a %d %b %H:%M'), due since $(date -r "$due" '+%a %d %b %H:%M')"
  exit 0
fi
[ "${1:-}" = --check ] && { echo "due: no full run since $(date -r "$due" '+%a %d %b %H:%M')"; exit 0; }

# Wait for the network after a wake or login, up to two minutes.
for _ in $(seq 24); do
  /usr/bin/nc -z -G 2 github.com 443 >/dev/null 2>&1 && break
  sleep 5
done

output="$("$HERE/update.sh" 2>&1)"
status=$?

problems="$(echo "$output" | grep -cE '^  (WARN|FAIL) ')"
if [ "$status" -eq 0 ]; then
  message="Everything is up to date."
else
  message="$problems item(s) need you. Ask Claude: /update, or see the log."
fi
/usr/bin/osascript -e "display notification \"$message\" with title \"Update agent\"" >/dev/null 2>&1
