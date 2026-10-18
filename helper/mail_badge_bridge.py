#!/usr/bin/env python3
"""Mail Badge Bridge - native messaging host (Unified for Plasma/Unity & Cairo-Dock).

Receives {"count": N} from the Thunderbird add-on and updates the badge
simultaneously on standard desktops (Plasma/Unity) and Cairo-Dock.
"""

import json
import os
import signal
import socket
import struct
import sys
from urllib.parse import unquote

# URI aplikacije za standardne desktop okruženja (Plasma/Unity)
APP_URI = "application://thunderbird.desktop"

# --- minimal D-Bus wire protocol (little endian) ---------------------------

class _W:
    def __init__(self):
        self.b = bytearray()

    def align(self, n):
        self.b += b"\0" * (-len(self.b) % n)

    def byte(self, v):
        self.b.append(v)

    def u32(self, v):
        self.align(4)
        self.b += struct.pack("<I", v)

    def i64(self, v):
        self.align(8)
        self.b += struct.pack("<q", v)

    def string(self, s):  # also used for object paths
        data = s.encode()
        self.u32(len(data))
        self.b += data + b"\0"

    def sig(self, s):
        self.byte(len(s))
        self.b += s.encode() + b"\0"

    def array(self, elem_align, items, write_item):
        self.u32(0)
        len_pos = len(self.b) - 4
        self.align(elem_align)
        start = len(self.b)
        for it in items:
            write_item(it)
        struct.pack_into("<I", self.b, len_pos, len(self.b) - start)


def _variant(w, sig, value):
    w.sig(sig)
    if sig in ("s", "o"):
        w.string(value)
    elif sig == "g":
        w.sig(value)
    elif sig == "x":
        w.i64(value)
    elif sig == "b":
        w.u32(1 if value else 0)
    else:
        raise ValueError(sig)


class SessionBus:
    def __init__(self):
        self.sock = self._connect()
        self.serial = 0
        self._auth()
        self._send(1, "/org/freedesktop/DBus", "org.freedesktop.DBus", "Hello",
                     destination="org.freedesktop.DBus")

    @staticmethod
    def _connect():
        addr = os.environ.get("DBUS_SESSION_BUS_ADDRESS",
                              f"unix:path=/run/user/{os.getuid()}/bus")
        for entry in addr.split(";"):
            if not entry.startswith("unix:"):
                continue
            params = {k: unquote(v) for k, v in
                      (p.split("=", 1) for p in entry[5:].split(",") if "=" in p)}
            if "path" in params:
                target = params["path"]
            elif "abstract" in params:
                target = "\0" + params["abstract"]
            else:
                continue
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            try:
                s.connect(target)
                return s
            except OSError:
                s.close()
        raise RuntimeError(f"cannot connect to D-Bus session bus: {addr}")

    def _auth(self):
        uid_hex = str(os.getuid()).encode().hex()
        self.sock.sendall(b"\0AUTH EXTERNAL " + uid_hex.encode() + b"\r\n")
        reply = b""
        while not reply.endswith(b"\r\n"):
            chunk = self.sock.recv(256)
            if not chunk:
                raise RuntimeError("D-Bus closed during auth")
            reply += chunk
        if not reply.startswith(b"OK"):
            raise RuntimeError(f"D-Bus auth failed: {reply!r}")
        self.sock.sendall(b"BEGIN\r\n")

    def _send(self, msg_type, path, interface, member, destination=None,
              body_sig=None, body=b""):
        self.serial += 1
        fields = [(1, "o", path), (2, "s", interface), (3, "s", member)]
        if destination:
            fields.append((6, "s", destination))
        if body_sig:
            fields.append((8, "g", body_sig))

        w = _W()

        def write_field(f):
            w.align(8)
            w.byte(f[0])
            _variant(w, f[1], f[2])

        w.byte(ord("l"))
        w.byte(msg_type)
        w.byte(0)
        w.byte(1)
        w.u32(len(body))
        w.u32(self.serial)
        w.array(8, fields, write_field)
        w.align(8)
        self.sock.sendall(bytes(w.b) + body)
        self._drain()

    def _drain(self):
        self.sock.setblocking(False)
        try:
            while self.sock.recv(4096):
                pass
        except BlockingIOError:
            pass
        finally:
            self.sock.setblocking(True)

    def emit_badge(self, count):
        quick_info = str(count) if count > 0 else ""

        # 1. Pokušaj slanja signala za Plasma/Unity standardna okruženja
        try:
            w_unity = _W()
            w_unity.string(APP_URI)
            w_unity.array(8, [("count", "x", count)], lambda it: (w_unity.align(8), w_unity.string(it[0]), _variant(w_unity, it[1], it[2])))

            self._send(
                4,  # 4 = Signal
                "/com/canonical/unity/launcherentry/thunderbird",
                "com.canonical.Unity.LauncherEntry",
                "Update",
                body_sig="sa{sv}",
                body=bytes(w_unity.b)
            )
        except Exception:
            pass

        # 2. Pokušaj slanja poziva za Cairo-Dock
        try:
            launcher_name = "01thunderbird"
            w_cairo = _W()
            w_cairo.string(quick_info)
            w_cairo.string(launcher_name)

            self._send(
                1,  # 1 = Method Call
                "/org/cairodock/CairoDock",
                "org.cairodock.CairoDock",
                "SetQuickInfo",
                destination="org.cairodock.CairoDock",
                body_sig="ss",
                body=bytes(w_cairo.b)
            )
        except Exception:
            pass


# --- native messaging ------------------------------------------------------

def read_message():
    raw_len = sys.stdin.buffer.read(4)
    if len(raw_len) < 4:
        return None
    length = struct.unpack("@I", raw_len)[0]
    return json.loads(sys.stdin.buffer.read(length))


def main():
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    bus = SessionBus()
    try:
        while True:
            msg = read_message()
            if msg is None:
                break
            bus.emit_badge(max(0, int(msg.get("count", 0))))
    finally:
        try:
            bus.emit_badge(0)  # Zatvaranje Thunderbirda: ukloni bedž
        except OSError:
            pass


if __name__ == "__main__":
    main()
