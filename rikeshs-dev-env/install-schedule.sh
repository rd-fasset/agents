#!/bin/bash
# Installs the rikeshs-dev-env agent as a launchd job: every Monday at 10:00, and at login. If the Mac is
# asleep at 10:00 on Monday, launchd runs it on wake. scheduled.sh makes sure it runs once a week.
#
# Install:   bash install-schedule.sh
# Uninstall: bash install-schedule.sh --uninstall

set -e
LABEL="com.rikesh.rikeshs-dev-env"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
if [ "${1:-}" = "--uninstall" ]; then
  rm -f "$PLIST"
  echo "rikeshs-dev-env schedule removed."
  exit 0
fi

mkdir -p "$HERE/logs" "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$HERE/scheduled.sh</string></array>
  <key>StartCalendarInterval</key>
  <dict><key>Weekday</key><integer>1</integer><key>Hour</key><integer>10</integer><key>Minute</key><integer>0</integer></dict>
  <key>RunAtLoad</key><true/>
  <key>ProcessType</key><string>Background</string>
  <key>StandardOutPath</key><string>$HERE/logs/launchd.log</string>
  <key>StandardErrorPath</key><string>$HERE/logs/launchd.log</string>
</dict>
</plist>
PLIST

launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Installed: Mondays 10:00 and at login. $(bash "$HERE/scheduled.sh" --check)"
