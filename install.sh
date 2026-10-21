#!/usr/bin/env bash
# Mail Badge Notifier / Bridge Installer
# Combines the Native Messaging helper, add-on builder, systemd headless service,
# GUI/headless toggle wrapper, and KDE/Wayland desktop integration.
set -euo pipefail
cd "$(dirname "$0")"

DESKTOP_FILE="org.mozilla.Thunderbird.desktop"
APP_NAME="thunderbird"
BINARY_PATH="/usr/bin/thunderbird"

case "${1:-}" in
  "") ;;
  --thunderbird)
    DESKTOP_FILE="org.mozilla.Thunderbird.desktop"
    APP_NAME="thunderbird"
    BINARY_PATH="/usr/bin/thunderbird"
    ;;
  --betterbird)
    DESKTOP_FILE="eu.betterbird.Betterbird.desktop"
    APP_NAME="betterbird"
    BINARY_PATH="/usr/bin/betterbird"
    ;;
  --desktop-file)
    DESKTOP_FILE="${2:?--desktop-file needs a name, e.g. thunderbird.desktop}"
    APP_NAME="${DESKTOP_FILE%%.*}"
    BINARY_PATH="/usr/bin/$APP_NAME"
    ;;
  -h|--help)
    echo "Usage:"
    echo "  ./install.sh                     # Thunderbird (default)"
    echo "  ./install.sh --betterbird        # Betterbird"
    echo "  ./install.sh --desktop-file NAME # Custom launcher"
    exit 0
    ;;
  *) echo "Unknown option: $1 (try --help)" >&2; exit 1 ;;
esac

# Validate launcher file name
if [[ ! "$DESKTOP_FILE" =~ ^[A-Za-z0-9._-]+\.desktop$ ]]; then
  echo "Invalid launcher name: $DESKTOP_FILE" >&2
  exit 1
fi

echo "[*] Cleaning up old processes and lock files..."
pkill -9 "$APP_NAME" 2>/dev/null || true
rm -f ~/.thunderbird/*.default*/parent.lock 2>/dev/null || true
rm -f ~/.thunderbird/*.default-release/parent.lock 2>/dev/null || true

# --- 1. BUILD ADD-ON XPI ---
echo "[*] Creating add-on package (.xpi)..."
if [ -d "addon" ]; then
    (cd addon && rm -f ../mail-badge-bridge.xpi \
      && python3 -m zipfile -c ../mail-badge-bridge.xpi manifest.json background.js)
else
    echo "[!] Warning: 'addon' directory not found."
fi

# --- 2. INSTALL PYTHON BRIDGE HELPER ---
echo "[*] Installing Python native bridge helper..."
BIN_BRIDGE="$HOME/.local/bin/mail_badge_bridge.py"
mkdir -p "$HOME/.local/bin"
if [ -f "helper/mail_badge_bridge.py" ]; then
    sed "s|^APP_URI = .*|APP_URI = \"application://$DESKTOP_FILE\"|" \
      helper/mail_badge_bridge.py > "$BIN_BRIDGE"
    chmod 755 "$BIN_BRIDGE"
else
    echo "[!] Warning: helper/mail_badge_bridge.py not found."
fi

# --- 3. NATIVE MESSAGING MANIFESTS ---
echo "[*] Setting up Native Messaging manifests..."
MANIFEST=$(cat <<EOF
{
  "name": "mail_badge_bridge",
  "description": "Mail Badge Bridge helper with gdbus emit support",
  "path": "$BIN_BRIDGE",
  "type": "stdio",
  "allowed_extensions": ["mail-badge-bridge@celest-watches.com", "mail-badge-bridge@bakatamas", "mail-badge-notifier@salexandarz"]
}
EOF
)

for dir in "$HOME/.mozilla/native-messaging-hosts" \
           "${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/native-messaging-hosts" \
           "$HOME/.thunderbird/native-messaging-hosts"; do
  mkdir -p "$dir"
  printf '%s\n' "$MANIFEST" > "$dir/mail_badge_bridge.json"
done

# --- 4. SYSTEMD HEADLESS SERVICE ---
echo "[*] Creating systemd headless service..."
mkdir -p ~/.config/systemd/user/
cat << EOF > ~/.config/systemd/user/$APP_NAME.service
[Unit]
Description=${APP_NAME^} Headless Background Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$BINARY_PATH --headless -no-remote
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

# --- 5. GUI WRAPPER SCRIPT ---
echo "[*] Setting up smart wrapper in ~/.local/bin/$APP_NAME..."
cat << EOF > "$HOME/.local/bin/$APP_NAME"
#!/usr/bin/env bash
# 1. Stop background service to release profile lock
systemctl --user stop $APP_NAME.service 2>/dev/null

# 2. Launch actual GUI with all passed arguments
$BINARY_PATH "\$@"

# 3. When the window is closed, restart the background service
systemctl --user start $APP_NAME.service 2>/dev/null
EOF
chmod +x "$HOME/.local/bin/$APP_NAME"

# --- 6. DESKTOP FILE OVERRIDE FOR WAYLAND/KDE ---
echo "[*] Configuring local .desktop file with absolute path..."
mkdir -p ~/.local/share/applications
system_desktop=""
for d in /usr/share/applications /usr/local/share/applications ~/.local/share/applications; do
  if [[ -f "$d/$DESKTOP_FILE" ]]; then
    system_desktop="$d/$DESKTOP_FILE"
    break
  fi
done

local_desktop="$HOME/.local/share/applications/$DESKTOP_FILE"
if [[ -n "$system_desktop" ]]; then
    cp "$system_desktop" "$local_desktop"
elif [[ ! -f "$local_desktop" ]]; then
    touch "$local_desktop"
fi

if [[ -f "$local_desktop" ]]; then
    if grep -q "^Exec=" "$local_desktop"; then
        sed -i "s|^Exec=.*|Exec=$HOME/.local/bin/$APP_NAME %u|g" "$local_desktop"
    else
        echo "Exec=$HOME/.local/bin/$APP_NAME %u" >> "$local_desktop"
    fi
fi

# --- 7. START SERVICE ---
echo "[*] Reloading systemd configuration and starting service..."
systemctl --user daemon-reload
systemctl --user enable --now "$APP_NAME.service"

echo ""
echo "[✔] Installation completed successfully!"
echo "    - Headless service: $APP_NAME.service"
echo "    - Wrapper script:   ~/.local/bin/$APP_NAME"
echo "    - Add-on .xpi file:  $(pwd)/mail-badge-bridge.xpi"
echo ""
echo "Next step: In Thunderbird, go to Add-ons and Themes -> gear icon -> Install Add-on From File..."
echo "           select mail-badge-bridge.xpi, then restart your mail app."
