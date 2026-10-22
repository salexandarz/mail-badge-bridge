#!/usr/bin/env bash
# Mail Badge Bridge uninstaller for Arch Linux
#
# Usage:
#   ./uninstall.sh                    # Thunderbird (default)
#   ./uninstall.sh --thunderbird      # Thunderbird
#   ./uninstall.sh --desktop-file NAME # Any custom .desktop launcher
set -euo pipefail
cd "$(dirname "$0")"

DESKTOP_FILE="org.mozilla.Thunderbird.desktop"
APP_NAME="thunderbird"

case "${1:-}" in
  ""|--thunderbird)
    DESKTOP_FILE="org.mozilla.Thunderbird.desktop"
    APP_NAME="thunderbird"
    ;;
  --betterbird)
    DESKTOP_FILE="eu.betterbird.Betterbird.desktop"
    APP_NAME="betterbird"
    ;;
  --desktop-file)
    DESKTOP_FILE="${2:?--desktop-file needs a name}"
    APP_NAME="$(echo "$DESKTOP_FILE" | cut -d'.' -f1 | tr '[:upper:]' '[:lower:]')"
    ;;
  -h|--help) sed -n 2,12p "$0"; exit 0 ;;
  *) echo "Unknown option: $1 (try --help)" >&2; exit 1 ;;
esac

echo "=================================================="
echo " Uninstalling Mail Badge Bridge for: $APP_NAME"
echo "=================================================="

echo "-> Stopping and removing systemd headless service..."
systemctl --user stop "$APP_NAME.service" 2>/dev/null || true
systemctl --user disable "$APP_NAME.service" 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/$APP_NAME.service"
systemctl --user daemon-reload 2>/dev/null || true

echo "-> Killing remaining application and helper processes..."
pkill -9 "$APP_NAME" 2>/dev/null || true
pkill -f "mail_badge_bridge" 2>/dev/null || true

echo "-> Removing wrapper and python helper from ~/.local/bin..."
rm -f "$HOME/.local/bin/$APP_NAME"
rm -f "$HOME/.local/bin/mail_badge_bridge.py"

echo "-> Removing local desktop launcher..."
rm -f "$HOME/.local/share/applications/$DESKTOP_FILE"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

echo "-> Removing native messaging manifests..."
rm -f "$HOME/.mozilla/native-messaging-hosts/mail_badge_bridge.json"
rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/native-messaging-hosts/mail_badge_bridge.json"

echo "-> Removing compiled .xpi add-on..."
rm -f "mail-badge-bridge.xpi"

echo "=================================================="
echo " Uninstallation completed successfully!"
echo "=================================================="
