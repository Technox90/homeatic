#!/usr/bin/env python3

import os
import platform
import sqlite3
import subprocess
import threading
import time
from pathlib import Path

from flask import Flask, jsonify, request, send_from_directory
from werkzeug.security import check_password_hash

APP_DIR = Path("/opt/pve-sensor-dashboard")
DB = Path("/var/lib/pve-sensor-dashboard/metrics.db")
CONTROL_HASH_FILE = Path("/etc/pve-sensor-dashboard/control.hash")
POWER_HELPER = "/usr/local/sbin/pve-sensor-powerctl"

app = Flask(__name__, static_folder=str(APP_DIR / "static"), static_url_path="")

RANGES = {
    "1h": 3600,
    "6h": 6 * 3600,
    "12h": 12 * 3600,
    "24h": 24 * 3600,
    "7d": 7 * 86400,
    "30d": 30 * 86400,
}

FIELDS = [
    "ts",
    "cpu_percent", "iowait_percent",
    "load1", "load5", "load15",
    "ram_percent", "ram_used", "ram_total",
    "swap_percent",
    "root_percent", "root_used", "root_total",
    "cpu_temp", "cpu_freq",
    "board_temp", "vrm_temp", "chipset_temp", "drive_temp", "gpu_temp",
    "cpu_fan_rpm", "system_fan_rpm", "vcore",
    "cpu_power_w", "cpu_core_power_w", "uncore_power_w", "dram_power_w",
    "gpu_power_w", "system_power_w", "gpu_util_percent",
    "net_rx_bps", "net_tx_bps",
    "disk_read_bps", "disk_write_bps",
    "uptime", "process_count",
    "vm_running", "vm_total", "ct_running", "ct_total",
    "pihole_queries_total", "pihole_queries_blocked",
    "pihole_blocked_percent",
]

_failed = {}
_failed_lock = threading.Lock()
MAX_FAILS = 5
LOCK_SECONDS = 300
FAIL_WINDOW = 600


def db_ro():
    return sqlite3.connect(f"file:{DB}?mode=ro", uri=True, timeout=5)


def pve_version():
    try:
        return subprocess.check_output(
            ["pveversion"],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=2,
        ).strip()
    except Exception:
        return "Proxmox VE"


def read_text(path):
    try:
        return Path(path).read_text().strip()
    except Exception:
        return ""


def cpu_model():
    try:
        for line in Path("/proc/cpuinfo").read_text().splitlines():
            if line.startswith("model name"):
                return line.split(":", 1)[1].strip()
    except Exception:
        pass
    return platform.processor() or "CPU"


def board_model():
    vendor = read_text("/sys/devices/virtual/dmi/id/board_vendor")
    name = read_text("/sys/devices/virtual/dmi/id/board_name")
    version = read_text("/sys/devices/virtual/dmi/id/board_version")
    return " ".join(x for x in (vendor, name, version) if x) or "Mainboard"


def client_ip():
    return request.headers.get("X-Real-IP", request.remote_addr or "unknown")


def verify_code(code):
    try:
        stored = CONTROL_HASH_FILE.read_text(encoding="utf-8").strip()
        return bool(stored) and check_password_hash(stored, code)
    except Exception:
        return False


def rate_state(ip):
    now = time.time()
    with _failed_lock:
        entry = _failed.get(ip)
        if not entry:
            return False, 0

        fails, first, locked_until = entry

        if locked_until > now:
            return True, int(locked_until - now) + 1

        if now - first > FAIL_WINDOW:
            _failed.pop(ip, None)

        return False, 0


def record_failure(ip):
    now = time.time()

    with _failed_lock:
        fails, first, locked_until = _failed.get(ip, (0, now, 0))

        if now - first > FAIL_WINDOW:
            fails, first, locked_until = 0, now, 0

        fails += 1

        if fails >= MAX_FAILS:
            locked_until = now + LOCK_SECONDS

        _failed[ip] = (fails, first, locked_until)

        return fails, locked_until


def clear_failures(ip):
    with _failed_lock:
        _failed.pop(ip, None)


@app.get("/")
def index():
    return send_from_directory(app.static_folder, "index.html")


@app.get("/api/health")
def health():
    try:
        con = db_ro()
        con.execute("SELECT 1 FROM metrics LIMIT 1").fetchone()
        con.close()
        return jsonify({"ok": True, "database": True})
    except Exception as exc:
        return jsonify({"ok": False, "database": False, "error": str(exc)}), 503


@app.get("/api/info")
def info():
    return jsonify({
        "hostname": platform.node(),
        "pve": pve_version(),
        "cpu_model": cpu_model(),
        "board_model": board_model(),
        "cpu_count": os.cpu_count(),
        "ranges": list(RANGES.keys()),
        "power_control": True,
        "power_note": (
            "CPU Package/Core/Uncore/DRAM = Intel RAPL soweit verfügbar. "
            "Package enthält bereits die CPU-Gesamtenergie und darf nicht mit den "
            "Unterdomänen addiert werden. GPU = GPU-Telemetrie; Gesamtserver = "
            "IPMI/DCMI soweit vom System unterstützt."
        ),
    })


@app.get("/api/current")
def current():
    try:
        con = db_ro()
        cols = ",".join(FIELDS)
        row = con.execute(
            f"SELECT {cols} FROM metrics ORDER BY ts DESC LIMIT 1"
        ).fetchone()
        con.close()

        if not row:
            return jsonify({"error": "Noch keine Messdaten vorhanden."}), 503

        return jsonify(dict(zip(FIELDS, row)))
    except Exception as exc:
        return jsonify({"error": str(exc)}), 503


@app.get("/api/history/<period>")
def history(period):
    seconds = RANGES.get(period)
    if not seconds:
        return jsonify({"error": "Ungültiger Zeitraum."}), 400

    try:
        con = db_ro()

        bucket = max(15, int(seconds / 650))
        numeric_fields = FIELDS[1:]

        select_parts = [
            f"CAST(ts / {bucket} AS INTEGER) * {bucket} AS ts"
        ]
        select_parts += [f"AVG({f}) AS {f}" for f in numeric_fields]

        since = int(time.time()) - seconds

        rows = con.execute(
            f"""
            SELECT {",".join(select_parts)}
            FROM metrics
            WHERE ts >= ?
            GROUP BY CAST(ts / {bucket} AS INTEGER)
            ORDER BY ts
            """,
            (since,),
        ).fetchall()

        con.close()

        out_fields = ["ts"] + numeric_fields
        return jsonify([
            dict(zip(out_fields, row))
            for row in rows
        ])

    except Exception as exc:
        return jsonify({"error": str(exc)}), 503


@app.post("/api/power/<action>")
def power(action):
    if action not in ("reboot", "poweroff"):
        return jsonify({"error": "Ungültige Aktion."}), 400

    ip = client_ip()
    locked, remaining = rate_state(ip)

    if locked:
        return jsonify({
            "error": f"Zu viele Fehlversuche. Noch {remaining} Sekunden gesperrt."
        }), 429

    payload = request.get_json(silent=True) or {}
    code = str(payload.get("code", ""))

    if not verify_code(code):
        fails, locked_until = record_failure(ip)

        if locked_until > time.time():
            return jsonify({
                "error": "Zu viele Fehlversuche. Diese IP ist 5 Minuten gesperrt."
            }), 429

        return jsonify({
            "error": f"Steuer-Code ist falsch. Fehlversuch {fails}/{MAX_FAILS}."
        }), 403

    clear_failures(ip)

    try:
        subprocess.run(
            ["sudo", "-n", POWER_HELPER, action],
            check=True,
            timeout=5,
        )
    except Exception as exc:
        return jsonify({
            "error": f"Power-Aktion konnte nicht gestartet werden: {exc}"
        }), 500

    message = (
        "Neustart wurde ausgelöst."
        if action == "reboot"
        else "Herunterfahren wurde ausgelöst."
    )

    return jsonify({
        "ok": True,
        "action": action,
        "message": message,
    })


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=9105)
