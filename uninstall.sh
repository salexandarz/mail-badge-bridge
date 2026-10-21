#!/usr/bin/env bash
set -e

APP_NAME="thunderbird"
if [[ "${1:-}" == "--betterbird" ]]; then
    APP_NAME="betterbird"
fi

echo "[*] Stopping and removing systemd service..."
systemctl --user stop "$APP_NAME.service" 2>/dev/null || true
systemctl --user disable "$APP_NAME.service" 2>/dev/null || true
rm -f ~/.config/systemd/user/"$APP_NAME.service"
systemctl --user daemon-reload

echo "[*] Removing wrapper script and Python bridge..."
rm -f ~/.local/bin/"$APP_NAME"
rm -f ~/.local/bin/mail_badge_bridge.py

echo "[*] Removing local .desktop files..."
rm -f ~/.local/share/applications/org.mozilla.Thunderbird.desktop
rm -f ~/.local/share/applications/eu.betterbird.Betterbird.desktop

echo "[*] Removing Native Messaging manifests and XPI package..."
rm -f ~/.mozilla/native-messaging-hosts/mail_badge_bridge.json
rm -f ~/.config/mozilla/native-messaging-hosts/mail_badge_bridge.json
rm -f ~/.thunderbird/native-messaging-hosts/mail_badge_bridge.json
rm -f mail-badge-bridge.xpi

echo "[*] Cleaning up lock files and processes..."
pkill -9 "$APP_NAME" 2>/dev/null || true
rm -f ~/.thunderbird/*.default*/parent.lock 2>/dev/null || true
rm -f ~/.thunderbird/*.default-release/parent.lock 2>/dev/null || true

echo "[✔] Removal completed successfully! System restored to factory state."
