#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
TEMPLATE="$SCRIPT_DIR/com.stresswatch.refresh-signing.plist"
DESTINATION="$HOME/Library/LaunchAgents/com.stresswatch.refresh-signing.plist"
TEMP_PLIST=$(mktemp)

cleanup() {
    rm -f "$TEMP_PLIST"
}
trap cleanup EXIT

escaped_project_dir=${PROJECT_DIR//&/\\&}
escaped_home=${HOME//&/\\&}
sed \
    -e "s|__PROJECT_DIR__|$escaped_project_dir|g" \
    -e "s|__HOME__|$escaped_home|g" \
    "$TEMPLATE" > "$TEMP_PLIST"

plutil -lint "$TEMP_PLIST" >/dev/null
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs/StressWatch"
install -m 0644 "$TEMP_PLIST" "$DESTINATION"
chmod +x "$SCRIPT_DIR/refresh-free-signing.sh"

launchctl bootout "gui/$(id -u)/com.stresswatch.refresh-signing" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$DESTINATION"

echo "StressWatch signing automation is installed for 15:00 on days 1, 6, 11, 16, 21, and 26."
