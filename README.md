# Mail Badge Notifier

## Extended Features in this Fork

This fork (`salexandarz/mail-badge-notifier`) builds upon the original `mail-badge-bridge` to transform it into a **complete, automated background email management and notification system**.

Key additions include:

- **Headless Background Service:** Runs Thunderbird/Betterbird in the background using a user-level `systemd` service (`--headless -no-remote`) so you receive mail notifications and taskbar badge updates continuously without keeping a full application window open.
- **Smart GUI Wrapper:** Automatically manages application locks (`parent.lock`). Launching the app via your desktop launcher temporarily stops the background service to open the GUI cleanly, and automatically resumes background mode upon closing.
- **KDE / Wayland Compatibility:** Configures launcher entries with absolute binary paths to ensure reliable launch behavior across desktop environments.
- **Universal Taskbar Badge Support:** Seamlessly updates taskbar badges across KDE Plasma, Unity, and **Cairo-Dock**.

### Cairo-Dock Setup Requirements:
To get the notification badges working correctly on your Thunderbird/Betterbird launcher in Cairo-Dock, ensure the following requirements are met:

1. **D-Bus Enabled:** Make sure D-Bus communication and integration are active in your Cairo-Dock configuration.
2. **Appearance & Captions:** Customize the visual style of the badge (such as text color, outlines, and background) inside Cairo-Dock under **Appearance** -> **Captions**.

---

Shows the **unread count of all your inboxes** as a badge on the **Thunderbird** (or Betterbird) taskbar icon on Linux.

<!-- Add a screenshot: save it as docs/screenshot.png and uncomment the line below.
![Unread badge on the Betterbird taskbar icon](docs/screenshot.png)
-->

## Why

Betterbird and Thunderbird have an "App icon badge" setting, but on Linux it often fails to send the count to the taskbar natively. KDE Plasma and other Linux desktop docks support these badges through the Unity `LauncherEntry` D-Bus API, so this project fills the gap:

- **A systemd user service** runs your mail client headless in the background.
- **A small WebExtension** sums up unread messages across all account Inboxes.
- **A Python helper** uses `gdbus` signals to update the taskbar badge in real time.
- **A smart wrapper** safely handles opening and closing the main GUI window without profile conflicts.

The badge updates instantly when mail arrives or is read, and stays active even when the GUI window is closed.

---

## Requirements

- Thunderbird or Betterbird **128 or newer**, installed natively (not as Flatpak or Snap; see [Limitations](#limitations)).
- A taskbar or dock supporting Unity `LauncherEntry` badges (e.g., **KDE Plasma**, **Cairo-Dock**).
- `systemd` (user session enabled).
- Python 3.

---

## Install

Clone the repository and run the installer:

```bash
git clone [https://github.com/salexandarz/mail-badge-notifier.git](https://github.com/salexandarz/mail-badge-notifier.git)
cd mail-badge-notifier
./install.sh

For Betterbird, pass --betterbird:
Bash

./install.sh --betterbird

If your launcher desktop file has a custom name:
Bash

./install.sh --desktop-file custom-launcher.desktop

Final Add-on Activation

After running install.sh:

    Open Thunderbird / Betterbird.

    Go to Add-ons and Themes → ⚙ → Install Add-on From File…

    Select mail-badge-bridge.xpi from the cloned repository folder.

    Restart your mail app once to complete WebExtension registration.

## Uninstall

To clean up all systemd services, wrapper scripts, Native Messaging hosts, and desktop shortcuts:
Bash

./uninstall.sh

For Betterbird cleanup:
Bash

./uninstall.sh --betterbird

## Troubleshooting
No badge at all

    Check Browser Console: Press Ctrl+Shift+J in your mail app and look for logs starting with mail-badge-bridge:

       # "No such native application" indicates the helper script isn't registered properly. Re-run ./install.sh.

    Test D-Bus Signal: Run the following command in terminal while the service is active (replace the desktop entry name if using Betterbird or a custom launcher):
    Bash

    gdbus emit --session --object-path /test \
      --signal com.canonical.Unity.LauncherEntry.Update \
      "application://org.mozilla.Thunderbird.desktop" \
      "{'count': <int64 5>, 'count-visible': <true>}"

    If no badge appears, unpin the taskbar icon, launch the app from your application menu, and pin it again.

    Monitor D-Bus Traffic:
    Bash

    dbus-monitor "interface='com.canonical.Unity.LauncherEntry'"

## Wrong unread count

The count includes every folder marked as an Inbox across all configured accounts, including local folders if present.

## Limitations

    Flatpak / Snap releases cannot trigger native messaging binaries outside their sandbox environment.

    GNOME does not support LauncherEntry badges natively out of the box without specific dock extensions.

## How It Works

    Service Management: The installer deploys a user systemd unit (thunderbird.service) running in --headless -no-remote mode.

    Unread Tracking: The WebExtension listens for unread count changes and sends updates through Native Messaging.

    Badge Bridge: The Python script receives messages from the extension and emits com.canonical.Unity.LauncherEntry.Update D-Bus signals.

    GUI Switching: The wrapper (~/.local/bin/thunderbird) handles stopping the background service when you open the application interface, releasing parent.lock, and resuming background monitoring when closed.

## Credits

    Originally created by Baka Tamás (mail-badge-bridge).

    Headless systemd service integration, GUI wrapper automation, and Cairo-Dock support maintained by salexandarz.

## License

[MIT](LICENSE)
